import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { resolve, dirname, join, relative } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const sourceOnly=process.argv.includes('--source-only');let errors=0;
function fail(message){errors++;console.error('FAIL:',message);}
function ok(message){console.log('OK:',message);}
if(Number(process.versions.node.split('.')[0])!==24)fail('Use Node.js 24 LTS for this package.');else ok('Node.js 24');
const required=['app/layout.tsx','app/page.tsx','app/auth/confirm/route.ts','app/auth/callback/route.ts','supabase/migrations/001_init.sql','supabase/migrations/002_refinements.sql','supabase/bootstrap.sql','package.json','README.md'];
for(const path of required)if(!existsSync(join(root,path)))fail(`Missing ${path}`);
const files=[];
function walk(dir){for(const e of readdirSync(dir,{withFileTypes:true})){if(['node_modules','.next','.git'].includes(e.name))continue;const path=join(dir,e.name);if(e.isDirectory())walk(path);else if(/\.(ts|tsx|mjs)$/.test(e.name))files.push(path);}}
walk(root);
const functions=new Set([...readFileSync(join(root,'supabase/migrations/001_init.sql'),'utf8').matchAll(/function\s+public\.(\w+)\(/gi),...readFileSync(join(root,'supabase/migrations/002_refinements.sql'),'utf8').matchAll(/function\s+public\.(\w+)\(/gi)].map(m=>m[1]));
let imports=0;let rpcs=0;
for(const path of files){const text=readFileSync(path,'utf8');for(const match of text.matchAll(/(?:from\s+|import\s+)["']([@.][^"']+)["']/g)){
 const spec=match[1];if(!spec.startsWith('@/')&&!spec.startsWith('.'))continue;
 const base=spec.startsWith('@/')?join(root,spec.slice(2)):resolve(dirname(path),spec);
 if(!['','.ts','.tsx','.mjs','.js','/index.ts','/index.tsx'].some(suffix=>existsSync(base+suffix)))fail(`Missing import ${spec} in ${relative(root,path)}`);else imports++;
 }
 for(const match of text.matchAll(/\.rpc\(["'](\w+)["']/g)){rpcs++;if(!functions.has(match[1]))fail(`Missing SQL function ${match[1]}`);}
}
ok(`${files.length} source files inspected; ${imports} local imports resolved; ${rpcs} literal RPC references checked`);
const pkg=JSON.parse(readFileSync(join(root,'package.json'),'utf8'));
for(const [name,version] of Object.entries({...pkg.dependencies,...pkg.devDependencies}))if(version==='latest'||version==='*')fail(`${name} uses an unbounded version`);
if(!sourceOnly){
 try{process.loadEnvFile(join(root,'.env.local'));}catch(error){if(error.code!=='ENOENT')fail('Could not read .env.local');}
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL||'';const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||'';
 try{if(new URL(url).protocol!=='https:'||url.includes('YOUR_PROJECT'))throw new Error();}catch{fail('Set a real HTTPS NEXT_PUBLIC_SUPABASE_URL in .env.local or your deployment environment.');}
 if(!key||/YOUR_|xxx/.test(key)||!key.startsWith('sb_publishable_'))fail('Set NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY. Never use a secret/service-role key.');
 if(key.startsWith('eyJ')){try{const payload=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString());if(payload.role!=='anon')fail('The browser key must be a legacy anon key or a publishable key.');}catch{fail('Invalid legacy browser key format.');}}
 if(!process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY||/YOUR_/.test(process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY))console.warn('NOTE: No Google Maps key. Maps will show a fallback; accounts, jobs and chat can still work.');
 if(!existsSync(join(root,'node_modules','next','package.json')))fail('Dependencies are not installed. Run npm install.');
 if(!existsSync(join(root,'package-lock.json')))console.warn('NOTE: No lockfile yet. Run npm install and commit the generated package-lock.json.');
}
if(errors){console.error(`\n${errors} issue(s) need attention.`);process.exitCode=1;}else console.log('\nPreflight passed. This does not replace a build or live database tests.');
