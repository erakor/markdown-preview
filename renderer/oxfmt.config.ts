import base from '@erakor/toolchain/oxfmt'

// preview.html is copied verbatim into the committed bundle (App/Resources/Renderer), so
// reformatting it would change a build output rather than just style.
const config = {
  ...base,
  ignorePatterns: ['src/vendor/**', 'src/preview.html', 'pnpm-lock.yaml'],
}

export default config
