// Load each script once. Forms with several editors call this at the same
// time, and loading tinymce again replaces the global that earlier editors
// were registered on.
const scriptPromises = {};

const loadJavascript = (url) => {
  scriptPromises[url] ||= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = url;
    script.onload = resolve;
    script.onerror = (error) => {
      delete scriptPromises[url];
      reject(error);
    };
    document.head.appendChild(script);
  });

  return scriptPromises[url];
}

const loadStylesheet = (href) => {
  // Create a new link element
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;

  // Append the link element to the head of the document
  document.head.appendChild(link);
}

export {
  loadJavascript,
  loadStylesheet
};