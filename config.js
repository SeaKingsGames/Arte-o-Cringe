// Configuración de Arte o Cringe.
// Este archivo es tuyo: cuando te pase un index.html nuevo, NO reemplaces este.
window.AOC_CONFIG = {
  // Supabase → Project Settings → API (Project URL y publishable key)
  SUPABASE_URL: 'https://nqmhakctydswrzhcpmsd.supabase.co',
  SUPABASE_KEY: 'sb_publishable_xvBpQBr5Bjnxk9oHKSOqYQ_M_wTRXne',

  // Dirección del juego (se usa para los enlaces de "Invitar" y "Compartir" y para volver de Mercado Pago y Google)
  WEB_URL: 'https://arteocringe.seakingsstudios.com/',

  // AdMob → Apps → Arte o Cringe
  ADMOB_APP_ID: 'ca-app-pub-7210216260904848~4965306582',
  ADMOB_BANNER: 'ca-app-pub-7210216260904848/8186541308',
  ADMOB_RECOMPENSA: 'ca-app-pub-7210216260904848/6897510365',

  // true = anuncios de prueba de Google (para ti y tus testers, no generan dinero ni te ponen en riesgo).
  // Cámbialo a false cuando el juego salga a producción.
  ADS_PRUEBA: true,

  // Cámbialo a true el día que el juego ya esté publicado en Google Play:
  // aparece el botón «Descargar para Android» en la web y en la página /descargar.
  PLAY_PUBLICO: false,

  // Cobros en la web con Mercado Pago. Ponlo en true cuando la función "pagos"
  // de Supabase ya tenga tu MP_ACCESS_TOKEN (ver la guía).
  MERCADOPAGO: true,

  // Anuncios en la web con AdSense. ADSENSE_CLIENT es tu ca-pub-… (AdSense → Cuenta).
  // ADSENSE_BANNER es el número de un bloque de anuncios de display (opcional).
  // ADSENSE_PRUEBA: true = anuncios de prueba; false cuando AdSense apruebe tu sitio.
  ADSENSE_CLIENT: '',
  ADSENSE_BANNER: '',
  ADSENSE_PRUEBA: true,

  // 'auto' = en la app de Android usa Google Play y AdMob; en la web, Mercado Pago y AdSense si están activos.
  PAYMENTS: 'auto',
  ADS: 'auto',
};
