# WordPress + Elementor local con Docker

Instalación de WordPress con Elementor **completamente autoconfigurada** para pruebas rápidas y levantamiento en local. Un comando y en 1–3 minutos tienes un sitio en español, con Elementor listo, página de inicio de ejemplo, captura de correos y phpMyAdmin.

Pensado para Windows (Docker Desktop), pero funciona igual en macOS y Linux.

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (en Windows, con el backend WSL 2 activado, que es el predeterminado)
- [Git](https://git-scm.com/download/win) (para clonar el repo)

## Inicio rápido

### Windows (PowerShell)

```powershell
git clone https://github.com/<tu-usuario>/wordpress-elementor-local.git
cd wordpress-elementor-local
.\wp.ps1 up
```

El navegador se abre solo cuando todo está listo.

> Si PowerShell dice que la ejecución de scripts está deshabilitada, usa:
> `powershell -ExecutionPolicy Bypass -File .\wp.ps1 up`

### Cualquier sistema

```bash
docker compose up -d
docker compose logs -f wpcli     # espera a ver "¡WordPress listo para pruebas!"
```

## Accesos

| Servicio        | URL                              | Usuario | Clave   |
| --------------- | -------------------------------- | ------- | ------- |
| Sitio           | http://localhost:8080            |         |         |
| Admin           | http://localhost:8080/wp-admin   | `admin` | `admin` |
| phpMyAdmin      | http://localhost:8081            | `root`  | `root`  |
| Correos (Mailpit) | http://localhost:8025          |         |         |

## Qué queda configurado automáticamente

**Tema y plugins**

- Tema **Hello Elementor** activo (los demás temas se eliminan)
- **Elementor** activo, sin asistente de bienvenida, sin avisos de tracking, usando los colores/tipografías del Kit, con soporte para entradas y páginas y subida de SVG/JSON habilitada
- **Query Monitor** para depurar
- **WordPress Importer** (configurable con `EXTRA_PLUGINS`)
- **WooCommerce** opcional (`ENABLE_WOOCOMMERCE=true`) con COP, Colombia, pago contra entrega y 3 productos de prueba

**Contenido**

- Página **Inicio** construida con Elementor (portada + 3 bloques) como página de inicio
- Páginas **Blog** y **Contacto**, y menú principal asignado al encabezado
- Se borran el post "Hola mundo", la página de ejemplo, Akismet y Hello Dolly

**Ajustes**

- Idioma `es_ES` (traducciones de núcleo, tema y plugins), zona horaria `America/Bogota`
- Enlaces permanentes `/%postname%/`, fecha `d/m/Y`, semana inicia el lunes
- Buscadores bloqueados, `WP_ENVIRONMENT_TYPE=local`
- `WP_DEBUG` + `WP_DEBUG_LOG` activos (el log queda en `wp-content/debug.log`, sin mostrar errores en pantalla)
- PHP con 512 MB de memoria y subidas de hasta 128 MB (lo que recomienda Elementor)
- Todo correo que envíe WordPress se captura en Mailpit (nada sale a internet)

## Comandos (Windows)

| Comando                         | Qué hace                                               |
| ------------------------------- | ------------------------------------------------------ |
| `.\wp.ps1 up`                   | Levanta todo y abre el navegador                        |
| `.\wp.ps1 down`                 | Apaga (conserva datos)                                  |
| `.\wp.ps1 reset`                | Borra todo y reinstala desde cero                       |
| `.\wp.ps1 logs`                 | Log de la autoconfiguración                             |
| `.\wp.ps1 status`               | Estado de los contenedores                              |
| `.\wp.ps1 cli plugin list`      | Ejecuta cualquier comando de WP-CLI                     |
| `.\wp.ps1 backup`               | Exporta la base de datos a `backups\`                   |

Equivalentes directos con Docker:

```bash
docker compose down            # apagar
docker compose down -v         # borrar todo (luego `docker compose up -d` reinstala)
docker compose run --rm --no-deps --entrypoint wp wpcli --path=/var/www/html plugin list
```

## Personalización

Copia `.env.example` como `.env` (el script `wp.ps1` lo hace solo) y cambia lo que necesites:

```ini
WP_PORT=8080                 # puerto del sitio
SITE_TITLE="Mi sitio"
ADMIN_USER=admin
ADMIN_PASS=admin
WP_LOCALE=es_ES              # o es_CO, es_MX, en_US...
EXTRA_PLUGINS="wordpress-importer contact-form-7 header-footer-elementor"
ENABLE_WOOCOMMERCE=false
```

Los plugins de `EXTRA_PLUGINS` son slugs de wordpress.org (lo que aparece en la URL del plugin). Tras cambiar `.env`, ejecuta `.\wp.ps1 up` otra vez: la configuración es idempotente y solo agrega lo que falta. Para partir de cero, usa `.\wp.ps1 reset`.

## ¿Dónde están los archivos de WordPress?

Viven en un **volumen de Docker** (`wp_data`), no en una carpeta de Windows. Así el sitio es mucho más rápido y no hay problemas de permisos. Para trabajar con ellos:

- **VS Code**: extensión *Dev Containers* → "Attach to Running Container" → `wordpress`, carpeta `/var/www/html`
- **Copiar un plugin tuyo al sitio**:
  `docker compose cp .\mi-plugin wordpress:/var/www/html/wp-content/plugins/`
  y luego `.\wp.ps1 cli plugin activate mi-plugin`
- **Ver el debug.log**:
  `docker compose exec wordpress tail -f /var/www/html/wp-content/debug.log`

## Servicios

| Servicio     | Imagen                   | Función                                   |
| ------------ | ------------------------ | ----------------------------------------- |
| `db`         | mariadb:11.4             | Base de datos                             |
| `wordpress`  | wordpress:php8.3-apache  | WordPress (Apache + PHP 8.3)              |
| `wpcli`      | wordpress:cli-php8.3     | Autoconfiguración con WP-CLI (y termina)  |
| `phpmyadmin` | phpmyadmin               | Administrador de base de datos            |
| `mailpit`    | axllent/mailpit          | Bandeja de correos de prueba              |

## Problemas comunes

- **"port is already allocated"**: otro programa usa el puerto. Cambia `WP_PORT`, `PMA_PORT` o `MAIL_PORT` en `.env`.
- **`setup.sh: \r: not found` o `$'\r'`**: el archivo quedó con finales de línea de Windows. El `.gitattributes` del repo lo evita; si editaste el archivo, guárdalo con finales **LF** (en VS Code, esquina inferior derecha: CRLF → LF).
- **La configuración terminó con error**: revisa `.\wp.ps1 logs`. Suele ser falta de internet al descargar plugins; vuelve a ejecutar `.\wp.ps1 up`.

## Créditos

Basado en la idea de [pedrozopayares/Wordpress-local-para-pruebas-r-pidas-con-docker](https://github.com/pedrozopayares/Wordpress-local-para-pruebas-r-pidas-con-docker), simplificado y enfocado en Elementor.

## Licencia

MIT
