export function setTitle(title) {
  document.title = title;
}

export function getScheme() {
  return location.protocol.replace(/:$/, '');
}

export function getHost() {
  return location.host;
}
