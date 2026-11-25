# Draft · Add an official dongle extension interface

Korea Projection v1.8.0's device identification, module loading, AOA guard, AP and teardown are useful across more dongle chipsets. An extension registered after package verification could declare supported USB IDs, kernel/SoC targets, module parameters, binding identity and AP regulatory profile. Keep the original boot-safety state machine and a single service as the owner. Require explicit owner opt-in, version the interface and verify the extensions independently before loading.

The attached patch demonstrates RTL8831BU on NX4 HEV 260902. In the development add-on, two package files are exchanged under exact SHA-256 gates because v1.8.0 has no extension registration interface. For an upstream contribution, the extension contract and permitted driver data format should be agreed with the maintainer before exposing it. No pull request has been opened.
