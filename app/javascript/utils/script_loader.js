const loadJavascript = (url) => {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = url;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
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