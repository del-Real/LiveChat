export const isEmail = (value) =>
  typeof value === 'string' && value.includes('@');

export const isStrongPassword = (value) =>
  typeof value === 'string' && value.length >= 8;

export const isNonEmpty = (value) =>
  value !== undefined && value !== null;
