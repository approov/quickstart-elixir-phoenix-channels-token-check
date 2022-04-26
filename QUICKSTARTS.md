# Approov Integration Quickstarts

[Approov](https://approov.io) is an API security solution used to verify that requests received by your backend services originate from trusted versions of your mobile apps.


## The Quickstarts

The quickstart code for the Approov backend server is split into two implementations. The first gets you up and running with basic token checking. The second uses a more advanced Approov feature, _token binding_. Token binding may be used to link the Approov token with other properties of the request, such as user authentication (more details can be found [here](https://approov.io/docs/latest/approov-usage-documentation/#token-binding)).
* [Approov token check quickstart](/docs/APPROOV_TOKEN_QUICKSTART.md)
* [Approov token check with token binding quickstart](/docs/APPROOV_TOKEN_BINDING_QUICKSTART.md)

Both the quickstarts are built from the unprotected example server defined [here](/src/unprotected-server/echo), thus you can use Git to see the code differences between them.

Code difference between the Approov token check quickstart and the original unprotected server:

```
git diff --no-index src/unprotected-server/echo src/approov-protected-server/token-check/echo
```

You can do the same for the Approov token binding quickstart:

```
git diff --no-index src/unprotected-server/echo src/approov-protected-server/token-binding-check/echo
```

Or you can compare the code difference between the two quickstarts:

```
git diff --no-index src/approov-protected-server/token-check/echo src/approov-protected-server/token-binding-check/echo
```


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
* [Approov Support](https://approov.zendesk.com/hc/en-gb/requests/new)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)
