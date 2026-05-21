package main

import (
	"bufio"
	"bytes"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

type Site struct {
	VarName    string
	StagedPath string // The internal path safe for //go:embed
	Domain     string
}

type Config struct {
	Port  string
	Sites []Site
}

const serverTemplate = `package main

import (
	"context"
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

{{range .Sites}}
//go:embed {{.StagedPath}}/*
var {{.VarName}}FS embed.FS
{{end}}

func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		next.ServeHTTP(w, r)
	})
}

func main() {
	{{range .Sites}}
	{{.VarName}}Sub, err := fs.Sub({{.VarName}}FS, "{{.StagedPath}}")
	if err != nil {
		log.Fatalf("Failed to create {{.VarName}} sub-filesystem: %v", err)
	}
	{{.VarName}}Handler := http.FileServer(http.FS({{.VarName}}Sub))
	{{end}}

	mux := http.NewServeMux()
	
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host := strings.Split(r.Host, ":")[0]

		switch host {
		{{range .Sites}}
		case "{{.Domain}}":
			{{.VarName}}Handler.ServeHTTP(w, r)
		{{end}}
		default:
			http.Error(w, "Site Not Found", http.StatusNotFound)
		}
	})

	protectedMux := securityHeadersMiddleware(mux)

	server := &http.Server{
		Addr:              ":{{.Port}}", 
		Handler:           protectedMux,
		ReadHeaderTimeout: 3 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20, 
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Starting hardened web server on %s...\n", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server crashed: %v\n", err)
		}
	}()

	<-stop
	log.Println("Shutdown signal received, shutting down gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel() 

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown due to error or timeout: %v", err)
	}

	log.Println("Server exited cleanly.")
}
`

func prompt(reader *bufio.Reader, msg string, defaultVal string) string {
	if defaultVal != "" {
		fmt.Printf("%s [%s]: ", msg, defaultVal)
	} else {
		fmt.Printf("%s: ", msg)
	}

	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	if input == "" {
		return defaultVal
	}
	return input
}

func main() {
	reader := bufio.NewReader(os.Stdin)
	var config Config

	fmt.Println("=======================================")
	fmt.Println("  Tusko Static Site Binary Generator")
	fmt.Println("=======================================")

	// Cleanup previous staging directory if it exists
	os.RemoveAll(".build_assets")
	
	// 1. Gather Site Configurations
	siteCount := 1
	for {
		fmt.Printf("\n--- Site #%d ---\n", siteCount)
		
		domain := prompt(reader, "Domain endpoint (e.g., rex.tusko.org)", "")
		if domain == "" {
			fmt.Println("Domain cannot be empty. Try again.")
			continue
		}

		path := prompt(reader, "Path to static files (e.g., ../../active/vps-01/)", "")
		if path == "" {
			fmt.Println("Path cannot be empty. Try again.")
			continue
		}

		// Sanitize path inputs
		path = strings.TrimSuffix(path, "/")
		path = filepath.Clean(path)

		if stat, err := os.Stat(path); os.IsNotExist(err) || !stat.IsDir() {
			fmt.Printf("Error: Directory '%s' does not exist. Try again.\n", path)
			continue
		}

		// Create a safe variable name from the domain
		varName := strings.ReplaceAll(domain, ".", "")
		varName = strings.ReplaceAll(varName, "-", "")

		// Stage the external files into the local workspace to satisfy //go:embed
		stagedPath := fmt.Sprintf(".build_assets/%s", varName)
		if err := os.MkdirAll(stagedPath, 0755); err != nil {
			log.Fatalf("Failed to create staging directory: %v", err)
		}

		fmt.Printf("[*] Staging files from %s to %s...\n", path, stagedPath)
		// Use cp -a to copy contents recursively, preserving permissions
		cpCmd := exec.Command("cp", "-a", path+"/.", stagedPath+"/")
		if err := cpCmd.Run(); err != nil {
			log.Fatalf("Failed to copy assets: %v", err)
		}

		config.Sites = append(config.Sites, Site{
			VarName:    varName,
			StagedPath: stagedPath, // The template now uses this safe, relative path
			Domain:     domain,
		})

		more := prompt(reader, "Add another site? (y/N)", "n")
		if strings.ToLower(more) != "y" {
			break
		}
		siteCount++
	}

	// 2. Gather Server Configurations
	fmt.Println("\n--- Server Configuration ---")
	config.Port = prompt(reader, "Port to listen on", "80")

	// 3. Gather Build Configurations
	fmt.Println("\n--- Build & Optimization Configuration ---")
	goos := prompt(reader, "Target OS (GOOS)", "linux")
	goarch := prompt(reader, "Target Architecture (GOARCH)", "amd64")
	outputName := prompt(reader, "Output binary name", "tusko-web")
	
	fmt.Println("\n[Alpine VPS Requirements]")
	staticLink := prompt(reader, "Enable static linking (CGO_ENABLED=0)? (y/N)", "y")
	stripDebug := prompt(reader, "Strip debug info to minimize size (-ldflags='-w -s')? (y/N)", "y")

	// 4. Generate Source Code
	fmt.Println("\n[*] Generating source code (generated_server.go)...")
	tmpl, err := template.New("server").Parse(serverTemplate)
	if err != nil {
		log.Fatalf("Template parsing failed: %v", err)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, config); err != nil {
		log.Fatalf("Template execution failed: %v", err)
	}

	err = os.WriteFile("generated_server.go", buf.Bytes(), 0644)
	if err != nil {
		log.Fatalf("Failed to write generated_server.go: %v", err)
	}

	// 5. Compile the Binary
	fmt.Printf("[*] Compiling binary '%s' for %s/%s...\n", outputName, goos, goarch)
	
	buildArgs := []string{"build", "-o", outputName}
	if strings.ToLower(stripDebug) == "y" {
		buildArgs = append(buildArgs, "-ldflags", "-w -s")
	}
	buildArgs = append(buildArgs, "generated_server.go")

	cmd := exec.Command("go", buildArgs...)
	
	envVars := os.Environ()
	envVars = append(envVars, fmt.Sprintf("GOOS=%s", goos), fmt.Sprintf("GOARCH=%s", goarch))
	if strings.ToLower(staticLink) == "y" {
		envVars = append(envVars, "CGO_ENABLED=0")
	}
	cmd.Env = envVars
	
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		log.Fatalf("Compilation failed: %v", err)
	}

	// Cleanup artifacts
	fmt.Println("[*] Cleaning up staging directories and source code...")
	os.RemoveAll(".build_assets")
	os.Remove("generated_server.go")

	// 6. Output Deployment Instructions
	fmt.Println("\n=======================================")
	fmt.Println("             SUCCESS!                  ")
	fmt.Println("=======================================")
	fmt.Printf("Binary compiled as: %s\n\n", outputName)
	fmt.Println("Deployment Instructions (Alpine Linux VPS):")
	fmt.Printf("1. Upload: scp %s root@<vps-ip>:/usr/local/bin/%s\n", outputName, outputName)
	if config.Port == "80" || config.Port == "443" {
		fmt.Println("2. Privileges: The server uses a privileged port. You must install libcap and grant bind permissions:")
		fmt.Printf("   apk add libcap && setcap 'cap_net_bind_service=+ep' /usr/local/bin/%s\n", outputName)
	}
	fmt.Printf("3. Service: Configure your OpenRC script to execute /usr/local/bin/%s\n", outputName)
}