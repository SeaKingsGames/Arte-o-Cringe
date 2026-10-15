// Configuración de Arte o Cringe.
// Este archivo es tuyo: cuando te pase un index.html nuevo, NO reemplaces este.
window.AOC_CONFIG = {
  // Supabase → Project Settings → API (Project URL y publishable key)
  SUPABASE_URL: 'https://nqmhakctydswrzhcpmsd.supabase.co',
  SUPABASE_KEY: 'sb_publishable_xvBpQBr5Bjnxk9oHKSOqYQ_M_wTRXne',

  // Tu sitio en Vercel (se usa para los enlaces de "Invitar" y "Compartir")
  WEB_URL: 'https://arte-o-cringe.vercel.app/',

  // AdMob → Apps → Arte o Cringe
  ADMOB_APP_ID: 'ca-app-pub-7210216260904848~4965306582',
  ADMOB_BANNER: 'ca-app-pub-7210216260904848/8186541308',
  ADMOB_RECOMPENSA: 'ca-app-pub-7210216260904848/6897510365',

  // true = anuncios de prueba de Google (para ti y tus testers, no generan dinero ni te ponen en riesgo).
  // Cámbialo a false cuando el juego salga a producción.
  ADS_PRUEBA: true,

  // 'auto' = en la app de Android usa Google Play y AdMob; en la web solo monedas y sin anuncios.
  PAYMENTS: 'auto',
  ADS: 'auto',
};
