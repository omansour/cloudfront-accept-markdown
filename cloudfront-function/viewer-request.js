import cf from 'cloudfront';

var LAMBDA_DOMAIN = 'LAMBDA_FUNCTION_URL_DOMAIN';

var STATIC_EXT = /\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|json|xml|pdf|zip|mp4|webp|avif|ttf|eot|map)$/i;

function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var uri = request.uri;

    var accept = headers['accept'] ? headers['accept'].value : '';

    if (accept.indexOf('text/markdown') === -1) {
        return request;
    }

    if (STATIC_EXT.test(uri)) {
        return request;
    }

    request.headers['x-content-format'] = { value: 'markdown' };

    var originalHost = headers['host'] ? headers['host'].value : '';

    cf.updateRequestOrigin({
        domainName: LAMBDA_DOMAIN,
        originAccessControlConfig: {
            enabled: true,
            signingBehavior: 'always',
            signingProtocol: 'sigv4',
            originType: 'lambda'
        },
        customHeaders: {
            'x-original-host': originalHost,
            'x-original-uri': uri
        }
    });

    return request;
}
