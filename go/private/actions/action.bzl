def action_with_go_env(ctx, go_toolchain, env=None, **kwargs):
  fullenv = dict(go_toolchain.env)
  if env:
    fullenv.update(env)
  ctx.action(env=fullenv, **kwargs)