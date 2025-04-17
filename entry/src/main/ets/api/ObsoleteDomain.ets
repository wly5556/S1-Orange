import { URL } from "./base";

export namespace ObsoleteDomain {
  const saraba1st = /^https:\/\/([^/]*\.)?saraba1st\.com(\/.*)?$/
  const patterns = [saraba1st]

  export function replace(url: string) {
    for (const p of patterns) {
      url = url.replace(p, (match, subdomain: string, path: string) => {
        return `https://${subdomain || ''}${URL.PRIMARY_DOMAIN}${path || ''}`;
      });
    }
    return url
  }
}
