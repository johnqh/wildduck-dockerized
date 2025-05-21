

const API_BASE_URL = process.env['WILDDUCK_API_URL'] || 'http://localhost:3000';
const ACCESS_TOKEN = process.env['ACCESS_TOKEN'] || 'somesecretvalue';

console.debug(ACCESS_TOKEN, API_BASE_URL);
export async function createUser(username: string, password: string): Promise<{ success: boolean, id: string }> {
  try {

    const res = await fetch(`${API_BASE_URL}/users?accessToken=${ACCESS_TOKEN}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',

        'X-Access-Token': ACCESS_TOKEN
      },
      body: JSON.stringify({ username, password, address: username }),
    });

    if (!res.ok) throw new Error(`Create failed: ${res.statusText}`);
    const { success, id, error } = await res.json() as { success: boolean, id: string, error?: string };
    if (!success) throw new Error(error);
    return { success, id };
  } catch (error) {
    console.error(error);
    throw error;
  }
}

export async function deleteUser(id: string) {
  const res = await fetch(`${API_BASE_URL}/users/${id}`, {
    headers: {
      'X-Access-Token': ACCESS_TOKEN
    },
    method: 'DELETE',
  });
  if (!res.ok) throw new Error(`Delete failed: ${res.statusText}`);
  return res.json();
}
