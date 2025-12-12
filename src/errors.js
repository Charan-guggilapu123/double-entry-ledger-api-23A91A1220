class APIError extends Error {
  constructor(status = 500, message = "Internal Server Error") {
    super(message);
    this.status = status;
  }
}

class BadRequest extends APIError {
  constructor(message = "Bad Request") {
    super(400, message);
  }
}
class NotFound extends APIError {
  constructor(message = "Not Found") {
    super(404, message);
  }
}
class UnprocessableEntity extends APIError {
  constructor(message = "Unprocessable Entity") {
    super(422, message);
  }
}

module.exports = { APIError, BadRequest, NotFound, UnprocessableEntity };
