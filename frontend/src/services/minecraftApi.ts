import api from './api'

export const minecraftApi = {
  verify: (username: string) =>
    api.post('/auth/register_minecraft', { username }),
}

export default minecraftApi
