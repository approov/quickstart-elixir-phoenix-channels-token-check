# Approov Integration Testing

[Approov](https://approov.io) is an API security solution used to verify that requests received by your backend services originate from trusted versions of your mobile apps.

## Testing the Approov Integration

Each Quickstart has at their end a dedicated section for testing, that will walk you through the necessary steps to use the Approov CLI to generate valid and invalid tokens to test your Approov integration without the need to rely on the genuine mobile app(s) using your backend.

* [Approov Token](/docs/APPROOV_TOKEN_QUICKSTART.md#test-your-approov-integration) test examples.
* [Approov Token Binding](/docs/APPROOV_TOKEN_BINDING_QUICKSTART.md#test-your-approov-integration) test examples.

### Testing with Postman

A ready-to-use Postman collection can be found [here](https://raw.githubusercontent.com/approov/postman-collections/main/quickstarts/hello-world/hello-world.postman_collection.json). It contains a comprehensive set of example requests to send to the backend server for testing. The collection contains requests with valid and invalid Approov tokens, and with and without token binding.

### Testing with Curl

An alternative to the Postman collection is to use cURL to make the API requests. Check some examples [here](https://github.com/approov/postman-collections/blob/main/quickstarts/hello-world/hello-world.postman_curl_requests_examples.md).

### The Dummy Secret

The valid Approov tokens in the Postman collection and cURL requests examples were signed with a dummy secret that was generated with `openssl rand -base64 64 | tr -d '\n'; echo`, therefore not a production secret retrieved with `approov secret -get base64`, thus in order to use it you need to set the `APPROOV_BASE64_SECRET`, in the `.env` file for each [Approov integration example](/src/approov-protected-server), to the following value: `h-CX0tOzdAAR9l15bWAqvq7w9olk66daIH-Xk-IAHhVVHszjDzeGobzNnqyRze3lw_WVyWrc2gZfh3XXfBOmww`.


## Issues

If you find any issue while following our instructions then just report it [here](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/issues), with the steps to reproduce it, and we will sort it out and/or guide you to the correct path.


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov Get Started](https://approov.io/product/demo)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://approov.io/blog/)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.io/contact)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)
