const TOKEN_KEY = 'tapsakay_token';

export function saveToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export const TEMP_DRIVER_EMAIL = 'driver@driver.com';
export const TEMP_DRIVER_PASSWORD = 'pw';
