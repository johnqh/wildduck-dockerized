import axios from 'axios';

// Base URL for the WildDuck API, defaulting to localhost:3000 if not set in environment
const API_BASE_URL = process.env['WILDDUCK_API_URL'] || 'http://localhost:3000';
// Access token for authentication, defaulting to 'somesecretvalue'
const ACCESS_TOKEN = process.env['ACCESS_TOKEN'] || 'somesecretvalue';

// Log the configured access token and API base URL for debugging purposes
// console.debug(ACCESS_TOKEN, API_BASE_URL);

/**
 * Creates a new user in the WildDuck system.
 * @param username The username for the new user.
 * @param password The password for the new user.
 * @returns A promise that resolves to an object indicating success and the user ID.
 * @throws An error if the user creation fails.
 */
export async function createUser(username: string, password: string): Promise<{ success: boolean, id: string }> {
  try {
    // Make a POST request to the /users endpoint using axios
    const res = await axios.post(`${API_BASE_URL}/users`,
      // Request body: username, password, and address (which is the same as username)
      { username, password, address: username },
      // Configuration object for the request, including headers
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Access-Token': ACCESS_TOKEN // Custom access token header
        },
      }
    );

    // axios automatically throws an error for non-2xx status codes,
    // so we don't need a separate !res.ok check here.
    // The response data is directly available in res.data
    const { success, id, error } = res.data as { success: boolean, id: string, error?: string };

    // If the 'success' flag in the response data is false, throw an error
    if (!success) {
      throw new Error(error || 'User creation failed without specific error message.');
    }

    // Return the success status and the new user's ID
    return { success, id };
  } catch (error) {
    // Log any errors that occur during the process
    console.error('Error creating user:', error);
    // Re-throw the error for the caller to handle
    throw error;
  }
}

/**
 * Deletes a user from the WildDuck system by their ID.
 * @param id The ID of the user to delete.
 * @returns A promise that resolves to the response data from the deletion.
 * @throws An error if the user deletion fails.
 */
export async function deleteUser(id: string) {
  try {
    // Make a DELETE request to the /users/:id endpoint using axios
    const res = await axios.delete(`${API_BASE_URL}/users/${id}`, {
      // Configuration object for the request, including headers
      headers: {
        'X-Access-Token': ACCESS_TOKEN // Custom access token header
      },
    });

    // axios automatically throws an error for non-2xx status codes.
    // Return the response data directly.
    return res.data;
  } catch (error) {
    // Log any errors that occur during the process
    console.error('Error deleting user:', error);
    // Re-throw the error for the caller to handle
    throw error;
  }
}
