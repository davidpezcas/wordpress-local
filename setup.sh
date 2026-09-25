#!/bin/sh
# ═══════════════════════════════════════════════════════════════
#  Autoconfiguracion de WordPress + Elementor con WP-CLI
#  Se ejecuta en cada `docker compose up`. Es idempotente:
#  si algo ya existe, lo deja como esta.
# ═══════════════════════════════════════════════════════════════

WP="php -d memory_limit=512M $(command -v wp) --path=/var/www/html"
W=/var/www/html

say() { printf '%s\n' "$*"; }

# ── 1. Esperar a que el contenedor de WordPress copie los archivos ──
say "Esperando archivos de WordPress..."
i=0
until [ -f "$W/wp-config.php" ] && [ -f "$W/wp-includes/version.php" ]; do
  i=$((i+1)); [ $i -ge 60 ] && { say "❌ WordPress no generó sus archivos"; exit 1; }
  sleep 2
done

say "Esperando base de datos..."
i=0
until $WP db check >/dev/null 2>&1; do
  i=$((i+1)); [ $i -ge 30 ] && { say "❌ Sin conexión a la base de datos"; exit 1; }
  sleep 2
done
say "Base de datos lista"

# ── 2. Instalar WordPress ──────────────────────────────────────
if ! $WP core is-installed 2>/dev/null; then
  say "Instalando WordPress..."
  $WP core install \
    --url="$SITE_URL" --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" \
    --admin_email="$ADMIN_EMAIL" --skip-email
  FIRST_RUN=1
else
  say "WordPress ya estaba instalado"
  FIRST_RUN=0
fi

# Mantener la URL correcta si cambias WP_PORT en .env
$WP option update home    "$SITE_URL" >/dev/null
$WP option update siteurl "$SITE_URL" >/dev/null

# ── 3. Idioma y ajustes generales ──────────────────────────────
say "Idioma: $WP_LOCALE"
$WP language core install "$WP_LOCALE" --activate >/dev/null 2>&1 || true

say "Ajustes del sitio..."
$WP option update blogname        "$SITE_TITLE"                >/dev/null
$WP option update blogdescription "Entorno local de pruebas"   >/dev/null
$WP option update timezone_string "$WP_TIMEZONE"               >/dev/null
$WP option update date_format     "d/m/Y"                      >/dev/null
$WP option update time_format     "H:i"                        >/dev/null
$WP option update start_of_week   1                            >/dev/null
$WP option update blog_public     0                            >/dev/null   # no indexar
$WP rewrite structure '/%postname%/' --hard >/dev/null 2>&1 || $WP rewrite structure '/%postname%/' >/dev/null

# Modo debug (errores al log, no en pantalla)
$WP config set WP_DEBUG          true  --raw >/dev/null
$WP config set WP_DEBUG_LOG      true  --raw >/dev/null
$WP config set WP_DEBUG_DISPLAY  false --raw >/dev/null
$WP config set WP_ENVIRONMENT_TYPE local     >/dev/null
$WP config set WP_MEMORY_LIMIT   512M        >/dev/null

# ── 4. Tema y plugins ──────────────────────────────────────────
install_plugin() {
  if $WP plugin is-installed "$1" 2>/dev/null; then
    $WP plugin activate "$1" >/dev/null 2>&1 || true
    say "$1"
  else
    say "  Instalando $1..."
    $WP plugin install "$1" --activate >/dev/null || say "  ⚠️  No se pudo instalar $1"
  fi
}

say "Tema Hello Elementor..."
if ! $WP theme is-installed hello-elementor; then
  $WP theme install hello-elementor --activate >/dev/null
else
  $WP theme activate hello-elementor >/dev/null 2>&1 || true
fi

say "Plugins..."
install_plugin elementor
for p in $EXTRA_PLUGINS; do install_plugin "$p"; done
if [ "$ENABLE_WOOCOMMERCE" = "true" ]; then install_plugin woocommerce; fi

# Traducciones de plugins y temas
$WP language plugin install --all "$WP_LOCALE" >/dev/null 2>&1 || true
$WP language theme  install --all "$WP_LOCALE" >/dev/null 2>&1 || true

# ── 5. Configurar Elementor (sin asistentes ni avisos) ─────────
say "Configurando Elementor..."
$WP option update elementor_onboarded          1    >/dev/null
$WP option update elementor_tracker_notice     1    >/dev/null
$WP option update elementor_allow_tracking     no   >/dev/null
$WP option update elementor_disable_color_schemes     yes >/dev/null   # usa colores del Kit
$WP option update elementor_disable_typography_schemes yes >/dev/null
$WP option update elementor_cpt_support '["post","page"]' --format=json >/dev/null
$WP option update elementor_unfiltered_files_upload 1 >/dev/null     # permite subir SVG/JSON
$WP option update hello_theme_settings_hide_admin_notice 1 >/dev/null 2>&1 || true

# ── 6. Limpiar contenido por defecto ───────────────────────────
if [ "$FIRST_RUN" = "1" ]; then
  say "🧹 Eliminando contenido de ejemplo..."
  $WP post delete 1 2 --force >/dev/null 2>&1 || true          # "Hola mundo" y "Pagina de ejemplo"
  $WP comment delete 1 --force >/dev/null 2>&1 || true
  $WP plugin delete akismet hello >/dev/null 2>&1 || true
  for t in $($WP theme list --status=inactive --field=name 2>/dev/null); do
    $WP theme delete "$t" >/dev/null 2>&1 || true
  done
fi

# ── 7. Página de inicio construida con Elementor ───────────────
page_id() { $WP post list --post_type=page --name="$1" --field=ID --posts_per_page=1 2>/dev/null; }

HOME_ID=$(page_id inicio)
if [ -z "$HOME_ID" ]; then
  say "Creando página de inicio con Elementor..."
  HOME_ID=$($WP post create --post_type=page --post_title="Inicio" --post_name="inicio" \
            --post_status=publish --porcelain)

  ELEMENTOR_DATA='[
   {"id":"a1c0001","elType":"container","isInner":false,
    "settings":{"content_width":"boxed","flex_direction":"column","flex_align_items":"center",
      "min_height":{"unit":"vh","size":70,"sizes":[]},"flex_justify_content":"center",
      "background_background":"gradient","background_color":"#1E1B4B","background_color_b":"#7C3AED",
      "background_gradient_angle":{"unit":"deg","size":135,"sizes":[]},
      "padding":{"unit":"px","top":"80","right":"24","bottom":"80","left":"24","isLinked":false}},
    "elements":[
      {"id":"a1c0002","elType":"widget","widgetType":"heading","isInner":false,
       "settings":{"title":"Tu WordPress + Elementor está listo","header_size":"h1","align":"center",
         "title_color":"#FFFFFF"},"elements":[]},
      {"id":"a1c0003","elType":"widget","widgetType":"text-editor","isInner":false,
       "settings":{"editor":"<p>Esta página fue creada automáticamente con Elementor. Edítala, bórrala o úsala como punto de partida.</p>",
         "text_color":"#E9E5FF","align":"center"},"elements":[]},
      {"id":"a1c0004","elType":"widget","widgetType":"button","isInner":false,
       "settings":{"text":"Editar con Elementor","align":"center","size":"lg",
         "link":{"url":"/wp-admin/post.php?post=__ID__&action=elementor","is_external":"","nofollow":""},
         "background_color":"#FFFFFF","button_text_color":"#1E1B4B"},"elements":[]}
    ]},
   {"id":"a1c0005","elType":"container","isInner":false,
    "settings":{"content_width":"boxed","flex_direction":"row","flex_wrap":"wrap","flex_gap":{"unit":"px","size":24,"column":"24","row":"24"},
      "padding":{"unit":"px","top":"64","right":"24","bottom":"64","left":"24","isLinked":false}},
    "elements":[
      {"id":"a1c0006","elType":"widget","widgetType":"icon-box","isInner":false,
       "settings":{"selected_icon":{"value":"fas fa-bolt","library":"fa-solid"},"title_text":"Rápido",
         "description_text":"Un solo comando levanta todo el entorno.","_flex_size":"grow"},"elements":[]},
      {"id":"a1c0007","elType":"widget","widgetType":"icon-box","isInner":false,
       "settings":{"selected_icon":{"value":"fas fa-cog","library":"fa-solid"},"title_text":"Autoconfigurado",
         "description_text":"Idioma, zona horaria, permalinks, tema y plugins listos.","_flex_size":"grow"},"elements":[]},
      {"id":"a1c0008","elType":"widget","widgetType":"icon-box","isInner":false,
       "settings":{"selected_icon":{"value":"fas fa-flask","library":"fa-solid"},"title_text":"Desechable",
         "description_text":"Rompe lo que quieras: un reset y vuelves a empezar.","_flex_size":"grow"},"elements":[]}
    ]}
  ]'
  ELEMENTOR_DATA=$(printf '%s' "$ELEMENTOR_DATA" | sed "s/__ID__/$HOME_ID/g" | tr -d '\n')
  ELEMENTOR_VERSION=$($WP plugin get elementor --field=version 2>/dev/null)

  $WP post meta update "$HOME_ID" _elementor_edit_mode     builder                  >/dev/null
  $WP post meta update "$HOME_ID" _elementor_template_type wp-page                  >/dev/null
  $WP post meta update "$HOME_ID" _elementor_version       "$ELEMENTOR_VERSION"     >/dev/null
  $WP post meta update "$HOME_ID" _wp_page_template        elementor_header_footer  >/dev/null
  $WP post meta update "$HOME_ID" _elementor_data          "$ELEMENTOR_DATA"        >/dev/null
fi

BLOG_ID=$(page_id blog)
[ -z "$BLOG_ID" ] && BLOG_ID=$($WP post create --post_type=page --post_title="Blog" --post_name="blog" --post_status=publish --porcelain)
[ -z "$(page_id contacto)" ] && $WP post create --post_type=page --post_title="Contacto" --post_name="contacto" --post_status=publish >/dev/null

$WP option update show_on_front  page       >/dev/null
$WP option update page_on_front  "$HOME_ID" >/dev/null
$WP option update page_for_posts "$BLOG_ID" >/dev/null

# Menú principal
if ! $WP menu list --fields=name --format=csv 2>/dev/null | grep -q "^Principal$"; then
  $WP menu create "Principal" >/dev/null
  $WP menu item add-post principal "$HOME_ID" >/dev/null
  $WP menu item add-post principal "$BLOG_ID" >/dev/null
  $WP menu item add-post principal "$(page_id contacto)" >/dev/null
  $WP menu location assign principal menu-1 >/dev/null 2>&1 || true
fi

# ── 8. WooCommerce (opcional) ──────────────────────────────────
if [ "$ENABLE_WOOCOMMERCE" = "true" ]; then
  say "🛒 Configurando WooCommerce..."
  $WP option update woocommerce_default_country "CO"   >/dev/null
  $WP option update woocommerce_currency        "COP"  >/dev/null
  $WP option update woocommerce_price_thousand_sep "." >/dev/null
  $WP option update woocommerce_price_decimal_sep  "," >/dev/null
  $WP option update woocommerce_price_num_decimals 0   >/dev/null
  $WP option update woocommerce_coming_soon "no"       >/dev/null
  $WP option update woocommerce_onboarding_profile '{"skipped":true}' --format=json >/dev/null
  $WP option update woocommerce_cod_settings '{"enabled":"yes","title":"Pago contra entrega"}' --format=json >/dev/null
  $WP wc tool run install_pages --user="$ADMIN_USER" >/dev/null 2>&1 || true
  if [ "$($WP post list --post_type=product --format=count)" = "0" ]; then
    for n in 1 2 3; do
      $WP wc product create --user="$ADMIN_USER" --name="Producto de prueba $n" \
        --regular_price="$((n*25000))" --status=publish >/dev/null 2>&1 || true
    done
  fi
fi

# ── 9. Correo → Mailpit (mu-plugin, sin plugins extra) ─────────
mkdir -p "$W/wp-content/mu-plugins"
cat > "$W/wp-content/mu-plugins/local-mailpit.php" <<'PHP'
<?php
/**
 * Plugin Name: Local → Mailpit
 * Description: Envía todos los correos al servidor Mailpit local (solo desarrollo).
 */
add_action( 'phpmailer_init', function ( $mail ) {
	$mail->isSMTP();
	$mail->Host     = 'mailpit';
	$mail->Port     = 1025;
	$mail->SMTPAuth = false;
	$mail->SMTPAutoTLS = false;
} );
PHP

# ── 10. Limpieza final ─────────────────────────────────────────
$WP elementor flush-css >/dev/null 2>&1 || true
$WP rewrite flush       >/dev/null 2>&1 || true
$WP cache flush         >/dev/null 2>&1 || true

cat <<EOF

════════════════════════════════════════════════════════
  ¡WordPress listo para pruebas!
════════════════════════════════════════════════════════
  Sitio:       $SITE_URL
  Admin:       $SITE_URL/wp-admin
  phpMyAdmin:  http://localhost:$PMA_PORT
  Correos:     http://localhost:$MAIL_PORT

  Usuario: $ADMIN_USER    Clave: $ADMIN_PASS
════════════════════════════════════════════════════════
EOF
