# FortiGate 7.6.2 — VPN de Acceso Remoto con Router Cisco (Infraestructura 3)

### Arlene Fernández Herrera · Matrícula: 2025-0730

**Seguridad de Redes · ITLA**

---

## 🎥 Video Demostrativo

**[▶ Ver video de demostración](https://youtu.be/REEMPLAZAR-CON-TU-ID)**

---

---

## 📋 Tabla de Contenido

1. [Objetivo del Laboratorio](#1-objetivo-del-laboratorio)
2. [Topología y Direccionamiento](#2-topología-y-direccionamiento)
3. [Procedimiento paso a paso](#3-procedimiento-paso-a-paso)
   - [Paso 1. Nube PNET y PC local](#paso-1-nube-pnet-y-pc-local)
   - [Paso 2. Switch de Usuarios (VLAN 10)](#paso-2-switch-de-usuarios-vlan-10)
   - [Paso 3. Router Cisco: VLAN 10, DHCP y NAT](#paso-3-router-cisco-vlan-10-dhcp-y-nat)
   - [Paso 4. Acceso inicial del FortiGate (CLI)](#paso-4-acceso-inicial-del-fortigate-cli)
   - [Paso 5. Interfaces del FortiGate (GUI)](#paso-5-interfaces-del-fortigate-gui)
   - [Paso 6. Verificar la conectividad del Usuario](#paso-6-verificar-la-conectividad-del-usuario)
   - [Paso 7. Usuario VPN, grupo y objeto de red del servidor](#paso-7-usuario-vpn-grupo-y-objeto-de-red-del-servidor)
   - [Paso 8. VPN de acceso remoto en el FortiGate (GUI)](#paso-8-vpn-de-acceso-remoto-en-el-fortigate-gui)
   - [Paso 9. Publicar el Web Server sin VPN](#paso-9-publicar-el-web-server-sin-vpn)
   - [Paso 10. Web Server (HTTPS y SSH)](#paso-10-web-server-https-y-ssh)
   - [Paso 11. Cliente VPN en Ubuntu (vpnc)](#paso-11-cliente-vpn-en-ubuntu-vpnc)
   - [Paso 12. Pruebas de verificación](#paso-12-pruebas-de-verificación)
4. [Capturas de Pantalla](#4-capturas-de-pantalla)
5. [Estructura del Repositorio](#5-estructura-del-repositorio)

---

## 1. Objetivo del Laboratorio

Esta práctica implementa una **VPN IPsec de acceso remoto (Remote-Site)** entre un **Usuario** (VM Ubuntu en la VLAN 10, detrás de un **Router Cisco**) y un **FortiGate v7.6.2** (lado Servidor). Todo se conecta a través de una **Nube de PNETLab** en `203.0.113.0/29`, que simula al ISP con IPs públicas.

* El **Usuario** (VLAN 10, `/25`, DHCP) puede acceder al **servidor web (HTTPS)** **sin necesidad de VPN**: el FortiGate publica el servidor con una IP pública (`203.0.113.4`).
* El **Usuario** solo puede acceder al servidor por **SSH** **a través de la VPN**: el puerto 22 no está publicado y no existe ruta hacia la red del servidor fuera del túnel. Se demuestra con `ssh` y `traceroute`, con la VPN conectada y desconectada.

La configuración y demostración del **FortiGate se hace por GUI**. El Router Cisco se configura por CLI. El laboratorio no requiere salida a Internet real.

---

## 2. Topología y Direccionamiento

> LAN internas derivadas de la matrícula **2025-0730** → base `20.25.30.0/24`. Red de la nube: `203.0.113.0/29` (rango reservado para documentación, RFC 5737).

### 2.1 Diagrama de Topología

```
                      ┌───────────────────────────┐
   PC local ──────────┤   Nube PNET (ISP / Cloud) │
   203.0.113.1        │       203.0.113.0/29      │
                      └─────┬───────────────┬─────┘
                            │               │
                     ┌──────┴───────┐ ┌─────┴────────┐
                     │ Router Cisco │ │   FortiGate  │
                     │ Et0/0 (WAN)  │ │ port1 (WAN)  │
                     │ 203.0.113.2  │ │ 203.0.113.3  │
                     │ Et0/1 (trunk)│ │ port2 (LAN)  │
                     │ └ Et0/1.10   │ │ 20.25.30.130 │
                     │  20.25.30.2  │ │              │
                     └──────┬───────┘ └─────┬────────┘
                            │ trunk VLAN 10 │ 20.25.30.128/28
                     ┌──────┴───────┐ ┌─────┴────────┐
                     │ SW-USUARIOS  │ │  Web Server  │
                     │ e0/0 trunk   │ │  HTTPS + SSH │
                     │ e0/1 acc.V10 │ │  (Estática)  │
                     └──────┬───────┘ └──────────────┘
                            │ VLAN 10 · 20.25.30.0/25
                     ┌──────┴───────┐
                     │   Usuario    │
                     │ Ubuntu (DHCP)│
                     └──────────────┘

         ┄┄┄┄┄┄┄ VPN de acceso remoto (IPsec, IKEv1 + XAUTH) ┄┄┄┄┄┄┄
            Usuario (vpnc) ──► FortiGate 203.0.113.3 (dial-up)
            IP asignada al cliente: 20.25.30.193 – 20.25.30.200

  Política de comunicación:
  ┌───────────────────────────────────────────────────────────────────┐
  │ Web (HTTPS)  : Usuario → 203.0.113.4:443 → Web Server, SIN VPN    │
  │ SSH          : Usuario → 20.25.30.131:22, SOLO con la VPN activa  │
  │ Sin VPN no hay ruta ni publicación del puerto 22 hacia el server  │
  └───────────────────────────────────────────────────────────────────┘
```

### 2.2 Tabla de Interfaces

**Nube PNET:**

| Elemento | Rol | Dirección IP | Máscara |
|---|---|---|---|
| **Red de la nube** | Segmento compartido PC + Cisco + FortiGate (ISP) | 203.0.113.0 | /29 |
| **PC local** | Acceso a la GUI del FortiGate | 203.0.113.1 | /29 |
| **IP pública del Web Server** | VIP en el FortiGate (`port1`) | 203.0.113.4 | /29 |

**SW-USUARIOS (switch L2):**

| Interfaz | Modo | VLAN | Conectado a |
|---|---|---|---|
| **e0/0** | Trunk (802.1Q) | 10 permitida | Router Cisco `Et0/1` |
| **e0/1** | Access | 10 | Usuario (Ubuntu) |

**Router Cisco (lado Usuarios):**

| Interfaz | Rol | Dirección IP | Máscara |
|---|---|---|---|
| **Ethernet0/0** | WAN hacia la Nube | 203.0.113.2 | /29 |
| **Ethernet0/1** | Trunk hacia SW-USUARIOS (sin IP) | — | — |
| **Ethernet0/1.10** | Gateway VLAN 10 (dot1Q 10) | 20.25.30.2 | /25 |

**FortiGate (lado Servidor):**

| Interfaz | Alias | Rol | Dirección IP | Máscara |
|---|---|---|---|---|
| **port1** | WAN-NUBE | WAN | 203.0.113.3 | /29 |
| **port2** | LAN-SERVIDOR | LAN | 20.25.30.130 | /28 |

### 2.3 Tabla de Dispositivos

| Dispositivo | Interfaz | Dirección IP | Máscara | Gateway | Método | Rol |
|---|---|---|---|---|---|---|
| **PC local** | Adaptador VMnet | 203.0.113.1 | /29 | — | Estática | Acceso a la GUI del FortiGate |
| **Router Cisco** | Et0/0 | 203.0.113.2 | /29 | — | Estática | WAN, NAT de los Usuarios |
| **Router Cisco** | Et0/1.10 | 20.25.30.2 | /25 | — | Estática | Gateway VLAN 10 y servidor DHCP |
| **FortiGate** | port1 | 203.0.113.3 | /29 | — | Estática | WAN, servidor VPN de acceso remoto |
| **FortiGate** | port2 | 20.25.30.130 | /28 | — | Estática | Gateway LAN Servidor |
| **SW-USUARIOS** | e0/0 · e0/1 | — | — | — | — | Switch L2: trunk hacia el Cisco, access VLAN 10 al Usuario |
| **Usuario** | ens / eth | 20.25.30.3 (rango) | /25 | 20.25.30.2 | **DHCP** | Cliente Ubuntu en VLAN 10 |
| **Usuario (túnel)** | tun0 | 20.25.30.193 – .200 | /32 | — | VPN (mode-config) | IP asignada por el FortiGate al conectar la VPN |
| **Web Server** | eth0 | 20.25.30.131 | /28 | 20.25.30.130 | **Estática** | Servidor HTTPS y SSH |

> El rango DHCP de VLAN 10 es `20.25.30.3 – 20.25.30.126`. El pool de la VPN (`20.25.30.193 – 20.25.30.200`) no se solapa con la red de Usuarios ni con la del Servidor.

---

## 3. Procedimiento paso a paso

Los pasos están en el orden en que se ejecutan. Cada uno depende de los anteriores.

> Los nombres de interfaz del Cisco (`Ethernet0/0`, `Ethernet0/1`) deben ajustarse a los que muestre `show ip interface brief` en la imagen usada en PNETLab.

---

### Paso 1. Nube PNET y PC local

Un nodo **Cloud** de PNETLab conecta `Et0/0` del Router Cisco, `port1` del FortiGate y el adaptador virtual de la PC local, todos en `203.0.113.0/29`.

**Adaptador de la PC** (el que usa la VM de PNETLab, por ejemplo VMnet8 o Host-only):

| Campo | Valor |
|---|---|
| IP | `203.0.113.1` |
| Máscara | `255.255.255.248` |
| Gateway | *(vacío)* |

**En PNETLab:**

1. Clic derecho en el área de trabajo → `Add an object → Network`.
2. Type: `Management(Cloud0)`, nombre `Nube-PNET`.
3. Conectar `Et0/0` del Router Cisco a `Nube-PNET`.
4. Conectar `port1` del FortiGate a `Nube-PNET`.
5. Conectar `Et0/1` del Router Cisco a `e0/0` de `SW-USUARIOS` (Paso 2).
6. Conectar `e0/1` de `SW-USUARIOS` a la VM Ubuntu (Usuario).
7. Conectar `port2` del FortiGate al Web Server.

---

### Paso 2. Switch de Usuarios (VLAN 10)

El puerto hacia el Router Cisco es un **trunk 802.1Q** y el puerto del Usuario es un **access en VLAN 10**. Consola del switch (script: [`scripts/sw-usuarios.txt`](scripts/sw-usuarios.txt)):

```bash
enable
configure terminal

hostname SW-USUARIOS

vlan 10
 name USUARIOS
exit

interface Ethernet0/0
 description Trunk hacia Router Cisco Et0/1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 10
 no shutdown
exit

interface Ethernet0/1
 description Usuario - VLAN 10
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
 no shutdown
exit

end
write memory
```

**Verificación:**
```bash
show vlan brief
show interfaces trunk
```
Debe mostrar VLAN 10 `USUARIOS` con `Et0/1` y el trunk `Et0/0` activo con VLAN 10 permitida.

> Ver evidencia: [01_switch_vlan10.png](screenshots/01_switch_vlan10.png)

---

### Paso 3. Router Cisco: VLAN 10, DHCP y NAT

El Router Cisco es el gateway de la VLAN 10 (router-on-a-stick), el servidor DHCP de los Usuarios y hace NAT (PAT) hacia la nube para que el FortiGate pueda responder al Usuario. Se pega un bloque `configure terminal … end` a la vez (script completo: [`scripts/cisco-base.txt`](scripts/cisco-base.txt)).

**3.1 — Interfaces, VLAN 10 y DHCP**

```bash
enable
configure terminal

hostname R-CISCO
no ip domain-lookup

interface Ethernet0/0
 description WAN hacia la Nube PNET
 ip address 203.0.113.2 255.255.255.248
 no shutdown
exit

interface Ethernet0/1
 description Trunk hacia SW-USUARIOS
 no ip address
 no shutdown
exit

interface Ethernet0/1.10
 description VLAN 10 - Usuarios
 encapsulation dot1Q 10
 ip address 20.25.30.2 255.255.255.128
exit

ip dhcp excluded-address 20.25.30.1 20.25.30.2

ip dhcp pool USUARIOS-V10
 network 20.25.30.0 255.255.255.128
 default-router 20.25.30.2
 dns-server 8.8.8.8 8.8.4.4
 lease 1
exit

end
write memory
```

**3.2 — NAT (PAT) de los Usuarios hacia la nube**

```bash
configure terminal

ip access-list extended NAT-USUARIOS
 permit ip 20.25.30.0 0.0.0.127 any
exit

interface Ethernet0/0
 ip nat outside
exit

interface Ethernet0/1.10
 ip nat inside
exit

ip nat inside source list NAT-USUARIOS interface Ethernet0/0 overload

end
write memory
```

> El Router Cisco **no** tiene ruta hacia `20.25.30.128/28` (red del servidor): esa red solo es alcanzable a través de la VPN.

**Verificación:**
```bash
show ip interface brief
show ip dhcp pool
show ip nat translations
```
`Et0/0` y `Et0/1.10` deben estar `up/up`.

> Ver evidencia: [02_cisco_interfaces.png](screenshots/02_cisco_interfaces.png), [03_cisco_dhcp.png](screenshots/03_cisco_dhcp.png), [04_cisco_nat.png](screenshots/04_cisco_nat.png)

---

### Paso 4. Acceso inicial del FortiGate (CLI)

Desde la consola del FortiGate (script: [`scripts/fortigate-cli.txt`](scripts/fortigate-cli.txt)):

```bash
config system interface
    edit "port1"
        set mode static
        set ip 203.0.113.3 255.255.255.248
        set allowaccess https ssh ping
        set role wan
    next
end
```

Acceder desde el navegador de la PC local a `https://203.0.113.3` con las credenciales por defecto (`admin` / contraseña vacía) y definir una contraseña segura.

> Ver evidencia: [05_cli_acceso_fortigate.png](screenshots/05_cli_acceso_fortigate.png)

---

### Paso 5. Interfaces del FortiGate (GUI)

**Ruta:** `Network → Interfaces`

**port1 — WAN-NUBE** (ya tiene IP desde el Paso 4; se completa el resto):

| Campo | Valor |
|---|---|
| Alias | `WAN-NUBE` |
| Role | `WAN` |
| Addressing mode | `Manual` |
| IP/Netmask | `203.0.113.3 / 255.255.255.248` |
| Administrative access | `HTTPS, SSH, Ping` |

**port2 — LAN-SERVIDOR:**

| Campo | Valor |
|---|---|
| Alias | `LAN-SERVIDOR` |
| Role | `LAN` |
| Addressing mode | `Manual` |
| IP/Netmask | `20.25.30.130 / 255.255.255.240` |
| Administrative access | `Ping` |

> Ver evidencia: [06_interfaces_fortigate.png](screenshots/06_interfaces_fortigate.png)

---

### Paso 6. Verificar la conectividad del Usuario

Con el Router Cisco y el FortiGate configurados, comprobar que el Usuario recibe IP por DHCP y llega a la nube **antes** de crear la VPN.

**Desde la PC local** (CMD o PowerShell):
```
ping 203.0.113.2
ping 203.0.113.3
```

**Desde el Usuario (Ubuntu):**
```bash
ip addr
ping -c 3 20.25.30.2
ping -c 3 203.0.113.3
```

El Usuario debe tener una IP del rango `20.25.30.3 – 20.25.30.126` con gateway `20.25.30.2`, y responder los pings al Router Cisco y al FortiGate (`203.0.113.3`, a través del NAT del Cisco). Si el ping de la PC falla, revisar el firewall de Windows (permitir ICMP).

> Ver evidencia: [07_ping_nube.png](screenshots/07_ping_nube.png), [08_usuario_dhcp.png](screenshots/08_usuario_dhcp.png)

---

### Paso 7. Usuario VPN, grupo y objeto de red del servidor

El asistente de la VPN exige un grupo de usuarios para autenticar al cliente, y la red del servidor se define como objeto para limitar a qué llega el cliente VPN.

**7.1 — Usuario local**

**Ruta:** `User & Authentication → User Definition → Create New → Local User`

| Campo | Valor |
|---|---|
| Username | `vpnuser` |
| Password | `Lab12345` |

**7.2 — Grupo de usuarios**

**Ruta:** `User & Authentication → User Groups → Create New`

| Campo | Valor |
|---|---|
| Name | `VPN-USER` |
| Type | `Firewall` |
| Members | `vpnuser` |

**7.3 — Objeto de dirección de la red del servidor**

**Ruta:** `Policy & Objects → Addresses → Create New → Address`

| Campo | Valor |
|---|---|
| Name | `Red-Servidor` |
| Type | `Subnet` |
| IP/Netmask | `20.25.30.128/28` |

> Ver evidencia: [09_usuario_grupo_fortigate.png](screenshots/09_usuario_grupo_fortigate.png), [10_objeto_red_servidor.png](screenshots/10_objeto_red_servidor.png)

---

### Paso 8. VPN de acceso remoto en el FortiGate (GUI)

**Ruta:** `VPN → VPN Wizard` — plantilla **Remote Access**. Nombre del túnel: `VPN-Remoto`. El asistente de 7.6.2 tiene tres bloques (**Remote Endpoint**, **VPN Tunnel**, **Local FortiGate**).

#### 8.1 Bloque VPN Tunnel

| Campo | Valor |
|---|---|
| VPN client type | Ícono de **FortiClient** (el escudo) |
| Authentication method | `Pre-shared key` |
| Pre-shared key | `Lab12345` |
| IKE | `Version 1` |
| Transport | `Auto` |
| Use Fortinet encapsulation | Desactivado |
| NAT traversal | `Enable` |
| User authentication method | `Phase 1 interface` |
| User group | `VPN-USER` |
| DNS Server | `Use System DNS` |
| Enable IPv4 Split Tunnel | Activado |

> **IKE `Version 1`:** el cliente `vpnc` usa IKEv1 con XAUTH (modo agresivo, clave compartida y usuario/contraseña). El asistente propone `Version 2` por defecto.
> **NAT traversal → `Enable`:** el Usuario llega al FortiGate a través del NAT del Router Cisco.
> **Tipo de cliente:** el ícono solo elige la plantilla del asistente. Con la plantilla de FortiClient las propuestas de cifrado quedan en DES, compatibles con el cifrado bajo del FortiGate; la plantilla de Cisco propone AES y no sirve en este equipo.

> Ver evidencia: [11_vpn_tunel_fortigate.png](screenshots/11_vpn_tunel_fortigate.png)

#### 8.2 Bloque Remote Endpoint

| Campo | Valor |
|---|---|
| Addresses to assign to connected endpoints | `20.25.30.193-20.25.30.200` |
| Subnet for connected endpoints | `255.255.255.255` |
| FortiClient settings → EMS SN verification | **Desactivado** |
| FortiClient settings → Save password | Activado (valor por defecto) |
| FortiClient settings → Auto Connect | Desactivado |
| FortiClient settings → Always up (keep alive) | Desactivado |

> **EMS SN verification → Desactivado:** la plantilla de FortiClient exige que el cliente sea un FortiClient registrado en un servidor EMS. El cliente `vpnc` no lo es, así que se desactiva aquí, antes de crear el túnel (viene activado por defecto).

#### 8.3 Bloque Local FortiGate

| Campo | Valor |
|---|---|
| Incoming interface that binds to tunnel | `port1 (WAN-NUBE)` |
| Create and add interface to zone | Activado (valor por defecto) |
| Local interface | `port2 (LAN-SERVIDOR)` |
| Local Address | `Red-Servidor` |

> **Local Address → `Red-Servidor`:** define a qué red llega el cliente VPN (split tunnel). Solo debe alcanzar la red del servidor, no `all`.

> Ver evidencia: [12_vpn_endpoint_local_fortigate.png](screenshots/12_vpn_endpoint_local_fortigate.png)

#### 8.4 Resumen y Submit

En la pantalla **Review** se listan los objetos que el asistente crea (grupos de direcciones, interfaz de Fase 1 y Fase 2, zona y políticas). Pulsar **Submit** y esperar a que termine **sin mensajes de error**.

> Ver evidencia: [13_vpn_resumen_fortigate.png](screenshots/13_vpn_resumen_fortigate.png)

#### 8.5 Verificar la Fase 1

Desde la consola del FortiGate (solo lectura):

```bash
show vpn ipsec phase1-interface VPN-Remoto
```

Debe mostrar `set mode aggressive`, `set proposal des-md5 des-sha1`, `set xauthtype auto`, `set authusrgrp "VPN-USER"`, el rango `ipv4-start-ip 20.25.30.193` / `ipv4-end-ip 20.25.30.200`, y **no** debe aparecer `set ems-sn-check enable`.

Revisar también en `Policy & Objects → Firewall Policy` las políticas `vpn_VPN-Remoto_*`: el tráfico del cliente VPN hacia `port2` debe hacerse solo hacia `Red-Servidor`.

> Ver evidencia: [14_vpn_fase1_fortigate.png](screenshots/14_vpn_fase1_fortigate.png)

---

### Paso 9. Publicar el Web Server sin VPN

El Usuario llega al servidor web por una IP pública (`203.0.113.4`) que el FortiGate traduce al servidor. Solo se publica el puerto **443**; el **22** (SSH) no se publica.

**9.1 — Virtual IP**

**Ruta:** `Policy & Objects → Virtual IPs → Create New → Virtual IP`

| Campo | Valor |
|---|---|
| Name | `VIP-Web-Server` |
| Interface | `port1 (WAN-NUBE)` |
| Type | `IPv4` (Static NAT) |
| External IP address/range | `203.0.113.4` |
| Map to IPv4 address/range | `20.25.30.131` |
| Port Forwarding | Activado |
| Protocol | `TCP` |
| External service port | `443` |
| Map to IPv4 port | `443` |

> Ver evidencia: [15_vip_fortigate.png](screenshots/15_vip_fortigate.png)

**9.2 — Política de firewall**

**Ruta:** `Policy & Objects → Firewall Policy → Create New`

| Campo | Valor |
|---|---|
| Name | `Web-Publico` |
| Incoming Interface | `port1 (WAN-NUBE)` |
| Outgoing Interface | `port2 (LAN-SERVIDOR)` |
| Source | `all` |
| Destination | `VIP-Web-Server` |
| Schedule | `always` |
| Service | `HTTPS` |
| Action | `ACCEPT` |
| NAT | ❌ Disabled |

> Ver evidencia: [16_politica_web_fortigate.png](screenshots/16_politica_web_fortigate.png)

---

### Paso 10. Web Server (HTTPS y SSH)

Servidor Ubuntu con Apache + certificado autofirmado y servidor SSH (script completo: [`scripts/webserver-https.sh`](scripts/webserver-https.sh)):

```bash
sudo apt update && sudo apt install -y apache2 openssl openssh-server
sudo openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout /etc/ssl/private/webserver.key \
  -out /etc/ssl/certs/webserver.crt \
  -subj "/C=DO/ST=SantoDomingo/L=SantoDomingo/O=ITLA/CN=20.25.30.131" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "subjectAltName=IP:20.25.30.131,IP:203.0.113.4"
sudo a2enmod ssl
# apuntar SSLCertificateFile / SSLCertificateKeyFile a los archivos generados en default-ssl.conf
sudo a2ensite default-ssl
sudo systemctl restart apache2
sudo systemctl enable --now ssh
```

Direccionamiento estático: `20.25.30.131/28`, gateway `20.25.30.130` (FortiGate, `port2`).

**Verificación en el servidor:**
```bash
systemctl status apache2 ssh
ss -tlnp | grep -E ':(22|443)'
```

---

### Paso 11. Cliente VPN en Ubuntu (vpnc)

El Usuario es una VM Ubuntu conectada a la VLAN 10. El cliente `vpnc` (compatible con IKEv1 + XAUTH) se configura con cifrado débil **solo porque el FortiGate del laboratorio admite únicamente DES** (script: [`scripts/vpnc-fortigate.conf`](scripts/vpnc-fortigate.conf)).

**11.1 — Verificar que vpnc soporta DES**

```bash
vpnc --version
```
La salida debe listar `des` en *Supported Encryptions* y `dh5` en *Supported DH-Groups*.

**11.2 — Archivo de configuración**

```bash
sudo tee /etc/vpnc/fortigate.conf > /dev/null <<'EOF'
IPSec gateway 203.0.113.3
IPSec ID vpn
IPSec secret Lab12345
IKE Authmode psk
Xauth username vpnuser
Xauth password Lab12345
IKE DH Group dh5
Enable weak encryption
Enable weak authentication
NAT Traversal Mode natt
EOF
```

| Parámetro | Valor | Corresponde en el FortiGate |
|---|---|---|
| `IPSec gateway` | `203.0.113.3` | IP de `port1` |
| `IPSec secret` | `Lab12345` | Pre-shared key del Paso 8 |
| `Xauth username` / `password` | `vpnuser` / `Lab12345` | Usuario del Paso 7 |
| `IKE DH Group` | `dh5` | Grupos DH 5 y 14 de la Fase 1 |
| `Enable weak encryption` | — | Propuesta `des-md5 des-sha1` |

> Ver evidencia: [17_vpnc_config.png](screenshots/17_vpnc_config.png)

---

### Paso 12. Pruebas de verificación

**12.1 — Sin VPN**

Desde el Usuario (Ubuntu, VLAN 10, IP por DHCP):

```bash
curl -k https://203.0.113.4/
```
Debe responder el Web Server: **el acceso web no necesita VPN**.

```bash
ssh web-server@20.25.30.131
ssh web-server@203.0.113.4
traceroute 20.25.30.131
```
Los tres deben **fallar o quedar sin respuesta**: no hay ruta hacia `20.25.30.128/28` y el puerto 22 no está publicado.

> Ver evidencia: [18_acceso_web_sin_vpn.png](screenshots/18_acceso_web_sin_vpn.png), [19_ssh_sin_vpn_fallo.png](screenshots/19_ssh_sin_vpn_fallo.png)

**12.2 — Con la VPN conectada**

```bash
sudo vpnc fortigate.conf
ip addr show tun0
ip route | grep tun0
```
`tun0` debe tener una IP del rango `20.25.30.193 – 20.25.30.200` y debe existir una ruta hacia `20.25.30.128/28` por `tun0`.

```bash
ssh usuario@20.25.30.131
traceroute 20.25.30.131
```
El SSH debe conectar y el `traceroute` debe salir por la interfaz `tun0`.

En el FortiGate, confirmar la sesión del cliente: `Log & Report → System Events → VPN Events` (negociación exitosa de `VPN-Remoto` con el usuario `vpnuser`) y, desde la consola:
```bash
diagnose vpn ike gateway list
```

> Ver evidencia: [20_vpnc_conectado.png](screenshots/20_vpnc_conectado.png), [21_ssh_con_vpn.png](screenshots/21_ssh_con_vpn.png), [22_traceroute_con_vpn.png](screenshots/22_traceroute_con_vpn.png), [23_vpn_events_fortigate.png](screenshots/23_vpn_events_fortigate.png)

**12.3 — Con la VPN desconectada**

```bash
sudo vpnc-disconnect
ssh usuario@20.25.30.131
```
El SSH debe **volver a fallar**, confirmando que solo funciona con la VPN activa.

> Ver evidencia: [24_ssh_vpn_caida.png](screenshots/24_ssh_vpn_caida.png)

**12.4 — Si la VPN no conecta**

1. Confirmar que ambos lados usan **IKEv1**, la **misma clave compartida** y propuestas **DES** (Paso 8.5 y archivo del Paso 11).
2. Confirmar que `203.0.113.3` responde al ping desde el Usuario (Paso 6).
3. Ver la negociación del lado del cliente: `sudo vpnc --debug 3 fortigate.conf`.
4. Ver la negociación del lado del FortiGate: `diagnose debug application ike -1` y `diagnose debug enable` (apagar con `diagnose debug disable`). `no proposal chosen` indica propuestas distintas; un rechazo de autenticación indica usuario, grupo o clave incorrectos.
5. Limpiar el estado antes de reintentar: `sudo vpnc-disconnect` en el Usuario y `diagnose vpn ike gateway flush name VPN-Remoto` en el FortiGate.

---

## 4. Capturas de Pantalla

Numeradas en el orden en que se toman durante el procedimiento.

| # | Archivo | Paso | Descripción |
|---|---|---|---|
| 01 | [`01_switch_vlan10.png`](screenshots/01_switch_vlan10.png) | 2 | SW-USUARIOS con `show vlan brief` y `show interfaces trunk`. |
| 02 | [`02_cisco_interfaces.png`](screenshots/02_cisco_interfaces.png) | 3 | `show ip interface brief` del Cisco: `Et0/0` y `Et0/1.10` en `up/up`. |
| 03 | [`03_cisco_dhcp.png`](screenshots/03_cisco_dhcp.png) | 3 | `show ip dhcp pool` del Cisco, rango `20.25.30.3–126`. |
| 04 | [`04_cisco_nat.png`](screenshots/04_cisco_nat.png) | 3 | Config de NAT del Cisco (`NAT-USUARIOS`). |
| 05 | [`05_cli_acceso_fortigate.png`](screenshots/05_cli_acceso_fortigate.png) | 4 | CLI del FortiGate con la config inicial de `port1` (203.0.113.3/29). |
| 06 | [`06_interfaces_fortigate.png`](screenshots/06_interfaces_fortigate.png) | 5 | `Network → Interfaces` del FortiGate: port1 WAN y port2 LAN-SERVIDOR. |
| 07 | [`07_ping_nube.png`](screenshots/07_ping_nube.png) | 6 | Ping desde la PC local a `203.0.113.2` y `203.0.113.3`. |
| 08 | [`08_usuario_dhcp.png`](screenshots/08_usuario_dhcp.png) | 6 | Usuario Ubuntu con IP por DHCP y ping al Cisco y al FortiGate. |
| 09 | [`09_usuario_grupo_fortigate.png`](screenshots/09_usuario_grupo_fortigate.png) | 7 | Usuario `vpnuser` y grupo `VPN-USER`. |
| 10 | [`10_objeto_red_servidor.png`](screenshots/10_objeto_red_servidor.png) | 7 | Objeto `Red-Servidor` (20.25.30.128/28). |
| 11 | [`11_vpn_tunel_fortigate.png`](screenshots/11_vpn_tunel_fortigate.png) | 8.1 | Asistente 7.6.2, bloque VPN Tunnel (FortiClient, IKE Version 1). |
| 12 | [`12_vpn_endpoint_local_fortigate.png`](screenshots/12_vpn_endpoint_local_fortigate.png) | 8.2–8.3 | Bloques Remote Endpoint y Local FortiGate. |
| 13 | [`13_vpn_resumen_fortigate.png`](screenshots/13_vpn_resumen_fortigate.png) | 8.4 | Pantalla Review del asistente con los objetos creados. |
| 14 | [`14_vpn_fase1_fortigate.png`](screenshots/14_vpn_fase1_fortigate.png) | 8.5 | `show vpn ipsec phase1-interface VPN-Remoto` con propuesta DES. |
| 15 | [`15_vip_fortigate.png`](screenshots/15_vip_fortigate.png) | 9.1 | Virtual IP `VIP-Web-Server` (203.0.113.4:443). |
| 16 | [`16_politica_web_fortigate.png`](screenshots/16_politica_web_fortigate.png) | 9.2 | Política `Web-Publico`. |
| 17 | [`17_vpnc_config.png`](screenshots/17_vpnc_config.png) | 11 | `vpnc --version` y archivo `/etc/vpnc/fortigate.conf`. |
| 18 | [`18_acceso_web_sin_vpn.png`](screenshots/18_acceso_web_sin_vpn.png) | 12.1 | `curl -k https://203.0.113.4/` respondiendo sin VPN. |
| 19 | [`19_ssh_sin_vpn_fallo.png`](screenshots/19_ssh_sin_vpn_fallo.png) | 12.1 | SSH y traceroute fallando sin VPN. |
| 20 | [`20_vpnc_conectado.png`](screenshots/20_vpnc_conectado.png) | 12.2 | `vpnc` conectado, `tun0` con IP del pool. |
| 21 | [`21_ssh_con_vpn.png`](screenshots/21_ssh_con_vpn.png) | 12.2 | SSH exitoso al servidor con la VPN activa. |
| 22 | [`22_traceroute_con_vpn.png`](screenshots/22_traceroute_con_vpn.png) | 12.2 | Traceroute al servidor por `tun0`. |
| 23 | [`23_vpn_events_fortigate.png`](screenshots/23_vpn_events_fortigate.png) | 12.2 | VPN Events del FortiGate con la negociación de `VPN-Remoto`. |
| 24 | [`24_ssh_vpn_caida.png`](screenshots/24_ssh_vpn_caida.png) | 12.3 | SSH fallando tras desconectar la VPN. |

---

## 5. Estructura del Repositorio

```
/
├── README.md                  ← este documento
├── screenshots/               ← capturas numeradas de cada configuración
├── scripts/
│   ├── sw-usuarios.txt        ← configuración del switch (VLAN 10, trunk/access)
│   ├── cisco-base.txt         ← interfaces, VLAN 10, DHCP y NAT del router Cisco
│   ├── fortigate-cli.txt      ← acceso inicial del FortiGate
│   ├── vpnc-fortigate.conf    ← configuración del cliente VPN en Ubuntu
│   └── webserver-https.sh     ← Apache + certificado autofirmado + SSH
├── running-configs/
│   ├── sw-usuarios-running-config.txt
│   ├── cisco-running-config.txt
│   └── fortigate-running-config.conf
└── entregable/
    └── ArleneFernandez_20250730_P5.txt
```

> Ajustar el número de práctica (`P5`) según lo indicado por el profesor. El video debe subirse al principio del repositorio (enlace colocado arriba en este README).
