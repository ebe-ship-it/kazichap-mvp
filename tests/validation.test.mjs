import test from 'node:test';
import assert from 'node:assert/strict';
import { validCoordinates, normalizePhone, positiveAmount, safeRedirect, paymentTotal } from '../lib/validation.ts';

test('local and international Tanzanian mobile numbers normalize consistently',()=>{
 for(const phone of ['0712345678','255712345678','+255 712 345 678','(0712) 345-678'])assert.equal(normalizePhone(phone),'+255712345678');
 assert.equal(normalizePhone('0654321098'),'+255654321098');
});
test('invalid phone numbers cannot silently pass',()=>{for(const phone of ['','123','+254712345678','07123456789','+255512345678','0712x45678'])assert.equal(normalizePhone(phone),null);});
test('coordinates handle boundaries and reject NaN/infinite/incomplete values',()=>{
 assert.equal(validCoordinates(-6.7924,39.2083),true);assert.equal(validCoordinates(-90,180),true);
 for(const coords of [[91,0],[0,-181],[NaN,1],[1,Infinity],[undefined,0]])assert.equal(validCoordinates(...coords),false);
});
test('rates reject blank, zero, negative, infinite, over-precision and unreasonable amounts',()=>{
 for(const value of ['', ' ',null,undefined,-1,0,Infinity,NaN,'NaN','1e8','0x10','12.123',100000001,1.234])assert.equal(positiveAmount(value),null);
 assert.equal(positiveAmount('15000'),15000);assert.equal(positiveAmount('1.25'),1.25);
});
test('fixed-price bill equals agreed amount',()=>assert.equal(paymentTotal(25000,'fixed',null),25000));
test('hourly bill requires time and calculates the total rather than the rate',()=>{
 assert.equal(paymentTotal(15000,'hourly',null),null);assert.equal(paymentTotal(15000,'hourly',90),22500);
 assert.equal(paymentTotal(1000,'hourly',1),16.67);
});
test('hourly time must be positive whole minutes within allowed range',()=>{
 for(const minutes of [0,-1,1.5,43201,Infinity,NaN])assert.equal(paymentTotal(15000,'hourly',minutes),null);
 assert.equal(paymentTotal(15000,'unexpected',60),null);
});
test('auth redirects preserve safe local paths and reject external navigation',()=>{
 assert.equal(safeRedirect('/match/example?tab=chat'),'/match/example?tab=chat');
 for(const value of [null,'https://evil.example','//evil.example','/\\evil.example','/%2fevil.example','/%5cevil.example','/\n/evil.example','/%0aevil','/%E0%A4%A'])assert.equal(safeRedirect(value),'/dashboard');
});
