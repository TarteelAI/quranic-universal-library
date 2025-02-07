class CookieStore {
  getItem(key) {
    let values = document.cookie.match(`(^|;)\\s*${key}\\s*=\\s*([^;]+)`);
    return values ? values.pop() : null;
  }

  setItem(key, val) {
    let date = new Date();
    let days = 300;
    date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
    let expires = "; expires=" + date.toGMTString();
    document.cookie = key + "=" + String(val) + expires + "; path=/";
  }

  removeItem(key, val){
    throw "remove item is not implemented for CookieStore"
  }
}

class LocalStore {
  get(key, fallback) {
    return this.getStore().getItem(this.transformKey(key)) || fallback;
  }

  set(key, val) {
    return this.getStore().setItem(this.transformKey(key), val);
  }

  remove(key){
    return this.getStore().removeItem(this.transformKey(key));
  }

  transformKey(key) {
    return `qul-${key}`;
  }

  getStore() {
    if ("object" == typeof localStorage) {
      return localStorage;
    } else {
      return new CookieStore();
    }
  }
}

export default LocalStore;
