# wireguard ansible

This playbook provisions an Alpine Linux WireGuard gateway with nftables-based peer access controls. It is designed to be safe to rerun for both fresh server setup and peer updates.

## quick start

1. Copy the example inventory:

   ```sh
   cp inventory/hosts.example.yaml inventory/hosts.yaml
   ```

2. Fill in the server address, SSH settings, WireGuard server private key, and peer public keys in `inventory/hosts.yaml`.

3. Run the playbook from this directory:

   ```sh
   ansible-playbook playbooks/wireguard.yaml
   ```

`inventory/hosts.yaml` is ignored by git. Keep real private keys, hostnames, and client details out of committed files.

## access control

The `can_talk_to` list is source-initiated. A peer can start connections only to the CIDRs listed under that peer. Replies for approved connections are allowed by nftables connection tracking, but the reverse peer cannot start a new connection unless its own `can_talk_to` list allows it.

```yaml
wireguard_peers:
  - name: admin-laptop
    ip: "10.44.0.2"
    public_key: "replace-with-admin-laptop-public-key"
    can_talk_to:
      - "10.44.0.0/24"

  - name: restricted-client
    ip: "10.44.0.3"
    public_key: "replace-with-restricted-client-public-key"
    can_talk_to:
      - "10.44.0.2/32"
```

In this example, `restricted-client` can start connections to `admin-laptop`, but not to other peers.

## important variables

- `wireguard_private_key`: server private key. keep this only in ignored or encrypted local files.
- `wireguard_address`: server tunnel address with CIDR, such as `10.44.0.1/24`.
- `wireguard_listen_port`: UDP port for WireGuard.
- `wireguard_interface`: interface name, defaulting to `wg0`.
- `wireguard_ssh_allowed_cidrs`: source CIDRs allowed to reach SSH.
- `wireguard_udp_allowed_cidrs`: source CIDRs allowed to reach the WireGuard UDP port.
- `wireguard_peers`: peer definitions and their source-initiated access rules.

## scope

This is intentionally limited to WireGuard server setup on Alpine Linux: packages, forwarding, WireGuard config, nftables policy, and OpenRC services. It does not configure unrelated server hardening, NAT internet egress, DNS, or client config generation.
