/**
 * Consistent JSON response helpers for the API.
 */

function success(res, data, message, statusCode) {
    const body = { success: true, data: data ?? null };
    if (message) body.message = message;
    res.status(statusCode || 200).json(body);
}

function error(res, statusCode, message, details) {
    const body = { success: false, message: message || 'Request failed' };
    if (details !== undefined) body.error = details;
    res.status(statusCode || 500).json(body);
}

function notFound(res, message) {
    error(res, 404, message || 'Not found');
}

function badRequest(res, message, details) {
    error(res, 400, message || 'Bad request', details);
}

function unavailable(res, message) {
    error(res, 503, message || 'Service temporarily unavailable');
}

module.exports = {
    success,
    error,
    notFound,
    badRequest,
    unavailable
};
