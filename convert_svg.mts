import fs from 'node:fs';
import { convert } from '@markdown-viewer/drawio2svg';

const xml = fs.readFileSync('document/source/cdc_fifo_microarchitecture.drawio', 'utf8');
const svg = convert(xml, { pageIndex: 0, padding: 10, scale: 1 });
fs.writeFileSync('document/source/cdc_fifo_microarchitecture.svg', svg);
console.log('WROTE', svg.length);
console.log(svg.slice(0, 80));
