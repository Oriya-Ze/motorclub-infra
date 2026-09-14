function handler(event) {
  var request = event.request;
  var host = request.headers.host.value.toLowerCase();

  if (host !== "${apex_host}") {
    return request;
  }

  var qs = [];
  var querystring = request.querystring;
  Object.keys(querystring).forEach(function (key) {
    var item = querystring[key];
    if (item.multiValue) {
      item.multiValue.forEach(function (mv) {
        qs.push(key + "=" + mv.value);
      });
    } else if (item.value) {
      qs.push(key + "=" + item.value);
    } else {
      qs.push(key);
    }
  });

  return {
    statusCode: 301,
    statusDescription: "Moved Permanently",
    headers: {
      location: { value: "https://${www_host}" + request.uri + (qs.length ? "?" + qs.join("&") : "") },
    },
  };
}
