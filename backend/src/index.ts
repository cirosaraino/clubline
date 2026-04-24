import { appEnv, env } from './config/env';
import { createApp } from './app';

const app = createApp();

app.listen(env.PORT, () => {
  console.log(
    `Clubline backend listening on port ${env.PORT} (appEnv=${appEnv}, nodeEnv=${env.NODE_ENV})`,
  );
});
