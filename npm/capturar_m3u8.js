const puppeteer = require('puppeteer');

async function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function capturarM3u8(urlInicial) {
  const browser = await puppeteer.launch({ headless: false });
  const page = await browser.newPage();

  let currentUrl = urlInicial;
  let m3u8Url = null;

  const adBlockList = [
    'doubleclick.net',
    'googlesyndication.com',
    'adservice.google.com',
    'ads.pubmatic.com',
    'pagead2.googlesyndication.com',
  ];
  await page.setRequestInterception(true);
  page.on('request', req => {
    if (adBlockList.some(ad => req.url().includes(ad))) {
      req.abort();
    } else {
      req.continue();
    }
  });

  page.on('framenavigated', async frame => {
    if (frame === page.mainFrame()) {
      const newUrl = frame.url();
      console.log('🔄 URL mudou para:', newUrl);

      if (newUrl === 'https://betteranime.net/') {
        console.log('⚠️ Redirecionado para a home! Voltando para a página anterior...');
        try {
          // Voltar para a página anterior (episódio original)
          await page.goto(currentUrl, { waitUntil: 'networkidle2' });
          console.log('🔙 Voltou para:', currentUrl);
        } catch (e) {
          console.error('Erro ao voltar para a URL anterior:', e.message);
        }
      } else {
        // Atualiza a url atual só se for diferente da home
        currentUrl = newUrl;
      }
    }
  });

  page.on('response', async response => {
    const respUrl = response.url();
    if (respUrl.endsWith('.m3u8')) {
      m3u8Url = respUrl;
      console.log('🎯 M3U8 encontrado:', m3u8Url);
    }
  });

  console.log('➡️ Abrindo URL inicial:', urlInicial);
  await page.goto(urlInicial, { waitUntil: 'networkidle2' });

  for (let i = 0; i < 5; i++) {
    await delay(10000);
    if (m3u8Url) break;
  }

  await browser.close();

  if (m3u8Url) {
    console.log('✅ Link final .m3u8:', m3u8Url);
    return { m3u8Url, currentUrl };
  } else {
    throw new Error('❌ Arquivo .m3u8 não encontrado');
  }
}

const url = process.argv[2];
if (!url) {
  console.error('Use: node script.js <URL>');
  process.exit(1);
}

capturarM3u8(url)
  .then(({ m3u8Url, currentUrl }) => {
    console.log('URL final do episódio:', currentUrl);
    console.log('Arquivo .m3u8:', m3u8Url);
    process.exit(0);
  })
  .catch(err => {
    console.error(err.message);
    process.exit(1);
  });
