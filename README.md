# Approov QuickStart - Elixir Phoenix Channels Token Check

[Approov](https://approov.io) is an API security solution used to verify that requests received by your backend services originate from trusted versions of your mobile apps.

This repo implements the Approov server-side request verification code in [Elixir](https://elixir-lang.org/), which performs the verification check before allowing valid traffic to be processed by the API endpoint.

This is an Approov integration quickstart example for the Elixir Phoenix framework, that uses the Channels library to check the Approov token. If you are looking for another Elixir integration you can check our list of [quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/), and if you don't find what you are looking for, then please let us know [here](https://approov.io/contact).


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Quickstarts](#approov-integration-quickstarts)
* [Testing](#testing-the-approov-integration)
* [Examples](#approov-integration-examples)
* [Useful Links](#useful-links)


## Why?

You can learn more about Approov, the motives for adopting it, and more detail on how it works by following this [link](https://approov.io/product). In brief, Approov:

* Ensures that accesses to your GraphQL API come from official versions of your apps; it blocks accesses from republished, modified, or tampered versions
* Protects the sensitive data behind your GraphQL API; it prevents direct API abuse from bots or scripts scraping data and other malicious activity
* Secures the communication channel between your app and your GraphQL API with [Approov Dynamic Certificate Pinning](https://approov.io/docs/latest/approov-usage-documentation/#approov-dynamic-pinning). This has all the benefits of traditional pinning but without the drawbacks
* Removes the need for an API key in the mobile app
* Provides DoS protection against targeted attacks that aim to exhaust the GraphQL API server resources to prevent real users from reaching the service or to at least degrade the user experience.

[TOC](#toc---table-of-contents)


## How it works?

This is a brief overview of how the Approov cloud service and the Elixir Phoenix Channels server fit together from a backend perspective. For a complete overview of how the mobile app and backend fit together with the Approov cloud service and the Approov SDK we recommend to read the [Approov overview](https://approov.io/product) page on our website.

### Approov Cloud Service

The Approov cloud service attests that a device is running a legitimate and tamper-free version of your mobile app.

* If the integrity check passes then a valid token is returned to the mobile app
* If the integrity check fails then a legitimate looking token will be returned

In either case, the app, unaware of the token's validity, adds it to every request it makes to the Approov protected GraphQL API(s).

### Elixir Phoenix Channels Server

The Elixir Phoenix Channels server ensures that the token supplied in the `Approov-Token` header is present and valid. The validation is done by using a shared secret known only to the Approov cloud service and the Elixir Phoenix Channels server.

The request is handled such that:

* If the Approov Token is valid, the request is allowed to be processed by the GraphQL API endpoint
* If the Approov Token is invalid, an HTTP 401 Unauthorized response is returned

You can choose to log JWT verification failures, but we left it out on purpose so that you can have the choice of how you prefer to do it and decide the right amount of information you want to log.

>#### System Clock
>
>In order to correctly check for the expiration times of the Approov tokens is very important that the Phoenix backend server is synchronizing automatically the system clock over the network with an authoritative time source. In Linux this is usually done with a NTP server.

[TOC](#toc---table-of-contents)


## Approov Integration Quickstarts

The quickstart code for the Approov Elixir Phoenix Channels server is split into two implementations. The first gets you up and running with basic token checking. The second uses a more advanced Approov feature, _token binding_. Token binding may be used to link the Approov token with other properties of the request, such as user authentication (more details can be found [here](https://approov.io/docs/latest/approov-usage-documentation/#token-binding)).
* [Approov token check quickstart](/docs/APPROOV_TOKEN_QUICKSTART.md)
* [Approov token check with token binding quickstart](/docs/APPROOV_TOKEN_BINDING_QUICKSTART.md)

Both the quickstarts are built from the unprotected example server defined in this Phoenix [project](/src/unprotected-server/echo).

You can use Git to see the code differences between the two quickstarts:

```
git diff --no-index src/approov-protected-server/token-check/echo/lib/approov_token.ex src/approov-protected-server/token-binding-check/echo/lib/approov_token.ex
```

[TOC](#toc---table-of-contents)


## Testing the Approov Integration

Each [Quickstart](#approov-integration-quickstarts) has at their end a dedicated section for testing. This section will walk you through the necessary steps to use the Approov CLI to generate valid and invalid tokens to test your Approov integration without the need to rely on the genuine mobile app(s) using your backend.

[TOC](#toc---table-of-contents)


## Approov Integration Examples

The code examples for the Approov quickstarts are extracted from this simple [Approov integration examples](/src/approov-protected-server) for the backend server:

* [Approov Token](/src/approov-protected-server/token-check/echo) protected example server.
* [Approov Token Binding](/src/approov-protected-server/token-binding-check/echo) protected example server.

This servers are available online to make it easy for you to use them as the backend to run the [Echo Chamber](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/src/echo-chamber-app) mobile app example. You can follow the [deployment guide](DEPLOYMENT.md) to deploy them yourself. This will allow you to have full control of the stack when playing around with the Approov integration to gain a better understanding of how simple and easy it is to integrate Approov in an Elixir Phoenix Channels server.

[TOC](#toc---table-of-contents)


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Live Demo](https://approov.io/product/demo)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://blog.approov.io)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.zendesk.com/hc/en-gb/requests/new)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)

[TOC](#toc---table-of-contents)
