// Accepts any POST/GET, holds the response for DELAY_MS, then answers 200.
import http from 'node:http';

const port = Number(process.env.PORT ?? 8099);
const delayMs = Number(process.env.DELAY_MS ?? 20000);

http
  .createServer((req, res) => {
    let bytes = 0;
    req.on('data', (chunk) => (bytes += chunk.length));
    req.on('end', () => {
      console.log(`${new Date().toISOString()} ${req.method} ${req.url} received ${bytes} bytes, answering in ${delayMs} ms`);
      setTimeout(() => {
        res.writeHead(200, { 'content-type': 'text/plain' });
        res.end('ok\n');
        console.log(`${new Date().toISOString()} ${req.method} ${req.url} answered`);
      }, delayMs);
    });
  })
  .listen(port, () => console.log(`slow server on http://localhost:${port}, delay ${delayMs} ms`));
