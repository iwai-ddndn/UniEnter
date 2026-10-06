import assert from 'node:assert/strict'
import worker from './worker.js'
const pair = await crypto.subtle.generateKey({name:'Ed25519'}, true, ['sign','verify'])
const jwk = await crypto.subtle.exportKey('jwk',pair.privateKey)
const secret = crypto.getRandomValues(new Uint8Array(32))
const hmac = await crypto.subtle.importKey('raw',secret,{name:'HMAC',hash:'SHA-256'},false,['sign'])
let tests=0
function env(enabled='true') {
 const store=new Map()
 return {LICENSE_EMAIL_ENABLED:enabled, RESEND_API_KEY:'dummy', MAIL_FROM:'UniEnter <licenses@notify.oc-to.com>',MAIL_REPLY_TO:'info@oc-to.com',LICENSE_PRIVATE_KEY:Buffer.from(jwk.d,'base64url').toString('base64'),LICENSE_PUBLIC_KEY:Buffer.from(jwk.x,'base64url').toString('base64'),POLAR_WEBHOOK_SECRET:'whsec_'+Buffer.from(secret).toString('base64'),POLAR_API_BASE:'https://polar.example',LICENSES:{store,async get(k,t){const v=store.get(k);return v===undefined?null:t==='json'?JSON.parse(v):v},async put(k,v){store.set(k,v)}}}
}
async function webhook(e) {
 const body=JSON.stringify({type:'order.paid',data:{id:'order-test',checkout_id:'checkout-test',customer:{email:'buyer@example.com'}}})
 const timestamp=Math.floor(Date.now()/1000).toString(),id='event-test'
 const sig=Buffer.from(await crypto.subtle.sign('HMAC',hmac,new TextEncoder().encode(`${id}.${timestamp}.${body}`))).toString('base64')
 return worker.fetch(new Request('https://worker.example/polar/webhook',{method:'POST',body,headers:{'webhook-id':id,'webhook-timestamp':timestamp,'webhook-signature':'v1,'+sig}}),e)
}
let calls=[]
function mock(response=()=>Response.json({id:'mail-test'})) {
 calls=[]
 globalThis.fetch=async(url,options)=>{assert.equal(url,'https://api.resend.com/emails');calls.push({headers:options.headers,body:JSON.parse(options.body)});return response()}
}
async function record(e){return e.LICENSES.get('order:order-test','json')}
function pass(name){tests++;console.log('PASS:',name)}
{
 const e=env('false');mock();assert.equal((await webhook(e)).status,200);assert.equal(calls.length,0);assert.equal((await record(e)).mail,undefined);pass('disabled: issue key without sending')
}
{
 const e=env();mock();assert.equal((await webhook(e)).status,200);const r=await record(e)
 assert.equal(calls.length,1);assert.equal(r.mail.status,'accepted');assert.equal(r.mail.id,'mail-test')
 assert.equal(calls[0].body.from,'UniEnter <licenses@notify.oc-to.com>');assert.equal(calls[0].body.reply_to,'info@oc-to.com');assert.deepEqual(calls[0].body.to,['buyer@example.com']);assert.ok(calls[0].body.text.includes(r.key));assert.ok(calls[0].body.text.includes('ライセンス'));assert.equal(calls[0].headers['Idempotency-Key'],'unienter-license/order-test')
 assert.deepEqual(await e.LICENSES.get('checkout:checkout-test','json'),r)
 assert.equal((await webhook(e)).status,200);assert.equal(calls.length,1);assert.equal((await record(e)).key,r.key);pass('success: key+instructions, accepted ID, duplicate webhook does not resend')
}
for(const status of [403,429,500]) {
 const e=env();mock(()=>new Response('not logged',{status}));assert.equal((await webhook(e)).status,503);const before=await record(e);assert.equal(before.mail.status,'pending');const attempt=calls[0]
 mock();assert.equal((await webhook(e)).status,200);assert.equal((await record(e)).key,before.key);assert.deepEqual(calls[0],attempt);pass(`HTTP ${status}: retry same key and idempotent payload`)
}
{
 const e=env();mock(()=>{throw new Error('network')});assert.equal((await webhook(e)).status,503);assert.equal((await record(e)).mail.status,'pending');pass('network failure remains pending')
}
{
 const e=env();delete e.RESEND_API_KEY;mock();assert.equal((await webhook(e)).status,503);assert.equal(calls.length,0);assert.equal((await record(e)).mail.status,'pending');pass('missing credential does not silently succeed')
}
{
 const e=env();mock(()=>Response.json({}));assert.equal((await webhook(e)).status,503);assert.equal((await record(e)).mail.status,'pending');pass('API success without message ID is not accepted')
}
{
 const e=env();await e.LICENSES.put('order:order-test',JSON.stringify({email:'buyer@example.com',key:'UNIENTER-HISTORICAL',issuedAt:'2026-01-01'}));mock();assert.equal((await webhook(e)).status,200);assert.equal(calls.length,0);pass('historical purchases are not automatically emailed')
}
{
 const e=env();e.POLAR_ACCESS_TOKEN='dummy'
 globalThis.fetch=async(url)=>{assert.equal(url,'https://polar.example/v1/checkouts/checkout-test');return Response.json({status:'succeeded',customer_email:'buyer@example.com'})}
 const res=await worker.fetch(new Request('https://worker.example/license?checkout_id=checkout-test'),e);assert.equal(res.status,200)
 const checkout=await e.LICENSES.get('checkout:checkout-test','json');assert.equal(checkout.mail.status,'pending')
 mock();assert.equal((await webhook(e)).status,200);assert.equal((await record(e)).key,checkout.key);assert.ok(calls[0].body.text.includes(checkout.key));pass('checkout-first issue reused by webhook; GET never sends mail')
}
{
 const e=env();mock(()=>new Response('',{status:500}));await webhook(e);e.LICENSE_EMAIL_ENABLED='false';mock();assert.equal((await webhook(e)).status,200);assert.equal(calls.length,0);pass('explicit disable stops pending sends')
}
{
 const e=env();delete e.MAIL_REPLY_TO;mock();assert.equal((await webhook(e)).status,503);assert.equal(calls.length,0);assert.equal((await record(e)).mail.status,'pending');pass('missing Reply-To keeps mail pending without sending')
}
console.log(`${tests} scenarios passed; random test keys and mocked fetch only`)
