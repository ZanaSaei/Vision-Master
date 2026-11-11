'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizePhone,
  hashPassword,
  verifyPassword,
  signSignupToken,
  verifySignupToken,
  signResetToken,
  verifyResetToken,
  validateUsername,
  validateGrade,
} = require('../src/auth');

process.env.JWT_SECRET = 'test_secret_key_12345';

test('auth: normalizePhone handles standard formats', () => {
  assert.equal(normalizePhone('09121234567'), '09121234567');
  assert.equal(normalizePhone('+989121234567'), '09121234567');
  assert.equal(normalizePhone('00989121234567'), '09121234567');
  assert.equal(normalizePhone('9121234567'), '09121234567');
  assert.equal(normalizePhone('0912-123-4567'), '09121234567');
  assert.equal(normalizePhone('invalid'), '');
  assert.equal(normalizePhone(''), '');
});

test('auth: password hashing and verification', () => {
  const password = 'my_secure_password_123';
  const hash = hashPassword(password);
  assert.ok(hash.includes(':'), 'hash contains salt separator');

  // Matching password
  assert.equal(verifyPassword(password, hash), true);

  // Wrong password
  assert.equal(verifyPassword('wrong_password', hash), false);

  // Empty / invalid parameters
  assert.equal(verifyPassword('', hash), false);
  assert.equal(verifyPassword(password, 'invalid_hash'), false);
  assert.equal(verifyPassword(password, ''), false);
});

test('auth: signup token generation and verification', () => {
  const phone = '09121234567';
  const token = signSignupToken(phone);
  assert.ok(token);

  const verifiedPhone = verifySignupToken(token);
  assert.equal(verifiedPhone, phone);

  assert.equal(verifySignupToken('invalid.token.here'), null);
  assert.equal(verifySignupToken(''), null);
});

test('auth: reset token generation and verification', () => {
  const phone = '09121234567';
  const token = signResetToken(phone);
  assert.ok(token);

  const verifiedPhone = verifyResetToken(token);
  assert.equal(verifiedPhone, phone);

  // Reset token cannot be verified as signup token
  assert.equal(verifySignupToken(token), null);
  assert.equal(verifyResetToken('invalid.token.here'), null);
});

test('auth: username validation', () => {
  assert.equal(validateUsername('ali_reza'), true);
  assert.equal(validateUsername('student12'), true);
  assert.equal(validateUsername('User_2026'), true);

  // Too short
  assert.equal(validateUsername('ab'), false);
  // Invalid characters
  assert.equal(validateUsername('ali reza'), false);
  assert.equal(validateUsername('user@domain'), false);
  assert.equal(validateUsername('علی'), false);
  assert.equal(validateUsername(''), false);
});

test('auth: school grade validation', () => {
  assert.equal(validateGrade(10), true);
  assert.equal(validateGrade(11), true);
  assert.equal(validateGrade(12), true);
  assert.equal(validateGrade('10'), true);
  assert.equal(validateGrade('11'), true);
  assert.equal(validateGrade('12'), true);

  assert.equal(validateGrade(9), false);
  assert.equal(validateGrade(13), false);
  assert.equal(validateGrade('invalid'), false);
});
