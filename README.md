## STRPY smart contract workflow

This smart contract provides 5 types of account groups:

1. Buyer - This account buys services and files

2. Shopkeeper - This account owns a file shop

3. Service Provider - This account deploys services for money

4. Developer - This account publishes service types

5. Smart Contract Owner
- Provides the initial RSA-PSS public key everyone else is derived from
- This account validates and hosts the marketplace of marketplaces and the markeplace of services
- This account hosts the reference initial services as a developer

### Initial Service Types

0. Contract Provider - this account provides the Smart Contract Owner functionality

1. Database Provider - this account allows encrypted database to be stored and accessed from his device

2. Filesystem Provider - this account allows encrypted files to be stored and accessed from his device 

3. Marketplace Provider - this account validates and displays a list of shops from the blockchain and resolves disputes this can be done customly using the smart contract API or by using a ```marketplace-miner``` which has a minimalistic marketplace ui and requires a Filesystem Provider and a Database Provider

4. Gateway Provider - this account allows his domain name to be used to proxy requests to other service providers (any service provider can use this provider for its anonymity)

5. Broker Provider 
- One of Buyer or Seller type.
- This account allows private money transfer between buyer and seller. 
- User can use this service to anonymize his payments for services or shops
- To use for receiving money encrypt multiple wallets with the RSA-OAEP key provided by the broker as an array ```encrypt([wallet, wallet])``` and provide the brokerId in your shopId
- Buyer encrypts his wallet during the ```createPurchase``` and supplies his brokerId after that encrypting the payload and signing the brokerId with his RSA-PSS, after that he invokes a request to the broker service after ```finalizePurchase``` or ```cancelPurchase```
- If the shopkeeper or the buyer uses a broker the smart contract will halt the payout
- The smart contract will await while the broker exhausts the ```createPurchase``` transaction balance 
- Buyer and seller use different brokers in this way the buyer's broker then should invoke the shopkeeper's broker and the sellers broker makes the final transaction to the smart contract without knowing the buyers wallet but knowing the transactionId
- The seller broker invokes the ```createPayout``` method on the smartcontract to all the multiple receiving wallets until the ```createPurchase``` balance is exhausted

6. Torrent Provider - this accounts allows to run webtorrent websocket dht for encrypted p2p data transfer

7. Coturn Provider - this accounts allows to run coturn to enable relay p2p connections

8. Validator Provider - this accounts validate the stability of the services to allow load balancing 

### Step 1 User registers for using a service provider service (each service should be registered separately so a multi service provider cannot deanon the user)

1. User downloads the Service Provider RSA-PSS key from the blockchain
2. User creates a new RSA-PSS keypair from the provider's public key
3. User creates a new RSA-OAEP keypair
4. User invokes the ```createServiceProviderServiceAccount``` method to publish his public keys and required by service params - this transaction id and the private keys will later be required for in app id and verification, the payment is defined by the service provider if skipped it will be defined as just gas price

### Step 2 Users pays for Services

1. User downloads the Service Provider RSA-OAEP key from the blockchain
2. User encrypts his userId with the provider's RSA-OEAP public key
3. User signs the transaction data like date, serviceId and etc with the private RSA-PSS key from previous step and also encrypts it with the RSA-OEAP and pays the service fee invoking the ```payForServiceProviderService``` method
4. When using the service the user signs the transactioId with the RSA-OAEP key and transfers it with other required service params
5. files during the service usage are stored in a folder derived as sha256 hex from transaction id from the ```createServiceProviderServiceAccount``` invocation
6. After paying for the service and using it the user can then invoke a ```rateServiceProvider``` to write a 0-5 rating or ```reportServiceProvider``` to report a problem with this service provider this is publicly displayed on the blockchain
7. Service Provider can invoke ```refundForServiceProviderService``` to write a comment back to ```reportServiceProvider``` or ```replyRateServiceProvider``` to reply to rating

### Step 3 User becomes Seller

1. Seller downloads a marketplace type Service Provider RSA-OAEP key from the blockchain
2. Seller encrypts his userId with the provider's RSA-OEAP public key
3. Seller creates a new RSA-OAEP keypair
3. Seller creates an starpy folder exports the mnemonic and id and signs it
4. Seller invokes the ```createShop``` transaction with the name of the shop and all the previous data including the public key from RSA-OAEP
5. Seller enables private listing by disclosing the private link
6. Seller enables public listing after invoking a ```validatePublicListingTransaction```
7. Marketplace Provider needs to validate the shop update and run the ```enablePublicListingForTransaction``` the approval speed metric is public for provider after this the shop is added to public list of marketplace shops

### Step 4 User becomes Buyer
1. Buyer visits a shop and downloads the marketplace provider RSA-PSS and the merchant RSA-OAEP public keys and validates that the shop has been validated by the marketplace and all info is created by the merchant and can write the seller using the RSA-OAEP privately 
2. Buyer decides to buy something from a shop
3. Buyer create a new RSA-OAEP keypair for this purchase
4. Buyer invokes the ```createPurchase``` function that allows the user to burn the crypto amount required by the bill in the shop he encrypts his order using the the RSA-OAEP cert from the seller and he adds his own RSA-OAEP public key so the seller can use it for delivery encryption, the he updates the info in the channel
5. Seller receives the transaction confirmation and can release the file
6. Seller downloads the RSA-OAEP, creates a new AES-GCM key and encrypts the AES-GCM key with the RSA-OAEP key
7. Seller encrypts the file and the link with AES-GCM, then shares the file using a Filesystem provider or p2p
8. Seller invokes the ```releaseItem``` with the encrypted link and the encrypted AES-GCM key, as well as a hash from the ```createPurchase``` release code and updates the info in the channel with the RSA-OAEP encrypted transactionId otherwise ```cancelPurchase``` is automatically invoked by the time set in the marketplace provider config
9. Buyer downloads the encrypted transactionId from the channel and now can go to the transaction on chain to get his link and key decrypts it with RSA-OAEP and then decrypts the link with AES-GCM downloads the file and decrypts it with AES-GCM
10. Buyer invokes ```finalizePurchase``` with the release code from the hash of ```releaseItem``` invocation or this function is automatically invoked by the time set in the marketplace provider config
11. If the delivery or the purchase is not compliant the user can invoke ```holdPurchase``` with the halt code from the ```createPurchase``` transaction and the marketplace provider now creates a chat with all 3 sides and needs to resolve this situation...
12. Marketplace Provider invokes ```cancelPurchase``` which returns money to the buyer or ```finalizePurchase``` which transfers money to the seller
13. Buyer can then invoke a ```rateSeller``` to write a 0-5 rating or ```reportSeller``` to report a problem with this seller this is publicly displayed on the blockchain
14. Shopkeeper can invoke ```refundForPurchase``` to write a comment back to ```reportSeller``` or ```replyRateSeller``` to reply to rating

### Becoming a service provider (all except contract provider)

1. Provider registers with the contract provider as in step 1
2. Provider creates a new RSA-PSS and RSA-OAEP keys
3. Provider invokes ```createServiceProvider```
3. Provider deploys an https mining service to a public url 
4. If the newly created service requires external services they should be paid for using the example in step 2 but the serviceId is the userId 
5. Provider invokes ```createServiceProviderService``` with his public keys his userId, serviceId, description, public url, mnemonic of his public db and his database provider id
6. Provider can now invoke ```rateServiceType``` to write a 0-5 rating or ```reportServiceType``` to report a problem

### Becoming a developer

1. Developer registers with contract provider in step 1
2. Developer creates a new RSA-PSS derived from step 1 and RSA-OAEP keys
3. Developer invokes ```createDeveloper``` with his public RSA-PSS cert
4. Developer publishes his service to a public github repo and the service image to dockerhub
5. Developer needs to supply code for the service validator that would measure the uptime of the service
6. Developer invokes ```createServiceType``` signing the dockerhub link with his RSA-PSS and creating a new servicetype
7. Developer invokes ```validateNewServiceType``` to allow public listing of the service and validation by the smart contract owner
8. Developer can update his service type by using the ```updateServiceType```
9. Developer can allow other developers to edit his service type ```allowEditServiceTypeParams```
10. Developer can react to other developers invoking ```rateDeveloper```


### All methods

#### Any user
1. ```createServiceProviderServiceAccount()```

#### Service Provider
2. ```createServiceProvider()```
3. ```createServiceProviderService()```
4. ```rateServiceType()```
5. ```reportServiceType()```

#### Developer 
6. ```createDeveloper()```
7. ```createServiceType()```
8. ```validateNewServiceType()```
9. ```updateServiceType()```
10. ```allowEditServiceTypeParams()```
11. ```rateDeveloper()```

####  