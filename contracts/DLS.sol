pragma solidity ^0.4.4;

contract DLS {
  /*
   * A container for publisher profile metadata.
   */
  struct Publisher {
    address id; // "0xabcde1234...20"
    string domain; // "nytimes.com"
    string name; // "New York Times"
  }

  /*
   * A container for publisher-reseller relationship data.
   * This is the equivalent of a single row in ads.txt
   */
  struct Seller {
    string domain; // SSP/Exchange Domain
    string id; // SellerAccountID
    Relationship rel; // PaymentsType
    string tagId; // TAGID - Trustworthy Accountability Group ID
  }

  /*
   * The various types of relationships
   * (can be extended along with ads.txt spec)
   */
  enum Relationship {
    Direct,
    Reseller
  }

  /*
   * a mapping of publisher addresses to their profile metadata.
   *
   * example
   * "0xabcd" -> Publisher = { address: "0xabcd", string: "nytimes.com", name: "New York Times" }
   *
   * publishers["0xabcd"]
   */
  mapping (address => Publisher) public publishers;

  /* a mapping of domains to publisher ids;
   *
   * example
   * "nytimes.com" -> "0xabcd"
   */
  mapping (bytes32 => address) public domainPublisher;

   /*
    * a mapping of publisher addresses to
    * their authorized sellers and their data.
    *
    * example
    * sellers[publisherAddress][resellerAddress] -> Seller
    *
    * Publishers ads.txt
    * Row 1 - reseller1.com, 1293sdf, direct, tagId
    * Row 2 - reseller2.com, 1293sdf, direct, tagId
    */
  mapping (address => mapping (bytes32 => Seller)) public sellers;

  /*
   * The owner of this contract.
   */
  address public owner;

  /*
   * Events, when triggered, record logs in the blockchain.
   * Clients can listen on specific events to get fresh data.
   */
  event _PublisherRegistered(address indexed id);
  event _PublisherDeregistered(address indexed id);
  event _SellerAdded(address indexed publisherId, bytes32 indexed sellerId);
  event _SellerRemoved(address indexed publisherId, bytes32 indexed sellerId);

  /*
   * A function modifier which limits execution
   * of the function to the "owner".
   */
  modifier only_owner () {
    if (msg.sender != owner) {
      revert();
    }

    // continue with code execution
    _;
  }

  /*
   * The constructor function, called only
   * once when this contract is initially deployed.
   */
  function DLS() {
    owner = msg.sender;
  }

  /*
   * Only the owner of the contract can register new publishers.
   */
  function registerPublisher(address id, string domain, string name) only_owner external {
    publishers[id] = Publisher(id, domain, name);
    domainPublisher[sha3(domain)] = id;
    _PublisherRegistered(id);
  }

  /*
   * The owner can also deregister existing publishers.
   */
  function deregisterPublisher(address id) only_owner external {
    string storage domain = publishers[id].domain;
    delete domainPublisher[sha3(domain)];
    delete publishers[id];
    _PublisherDeregistered(id);
  }

  /*
   * Check if publisher is registered
   */
  function isRegisteredPublisher(address id) external constant returns (bool) {
    if (publishers[id].id != 0) {
      return true;
    }

    return false;
  }

  /*
   * Check if publisher is registered by domain
   */
  function isRegisteredPublisherDomain(string domain) external constant returns (bool) {
    if (domainPublisher[sha3(domain)] != 0) {
      return true;
    }

    return false;
  }

  /*
   * Once registered, publishers are free to add certified sellers.
   */
  function addSeller(string sellerDomain, string sellerId, Relationship sellerRel, string sellerTagId) external {
    address sender = msg.sender;

    /*
     * First, check that this ethereum address
     * is a registered publisher.

     * If their "id" has been set, then they have
     * been registered by the owner.

     * Note - in Ethereum, mapping values are initiated
     * to all 0s if not set.
     */
    if (publishers[sender].id != 0) {
      bytes32 hash = sha3(sellerDomain, sellerId);
      sellers[sender][hash] = Seller(sellerDomain, sellerId, sellerRel, sellerTagId);
      _SellerAdded(sender, hash);
    }
  }

  /*
   * Publishers can also remove sellers at will.
   */
  function removeSeller(string sellerDomain, string sellerId) external {
    address sender = msg.sender;

    /*
     * Check that this ethereum address is a registered publisher.
     */
    if (publishers[sender].id != 0) {
      bytes32 id = sha3(sellerDomain, sellerId);
      delete sellers[sender][id];
      _SellerRemoved(sender, id);
    }
  }

  /*
   * Return seller struct for publisher id
   */
  function getSellerForPublisher(address id, string sellerDomain, string sellerId) external constant returns (string, string, uint, string) {
    bytes32 hash = sha3(sellerDomain, sellerId);
    Seller storage seller = sellers[id][hash];

    // TODO: better way
    uint rel = 0;

    if (seller.rel == Relationship.Reseller) {
      rel = 1;
    }

    return (seller.domain, seller.id, rel, seller.tagId);
  }

  /*
   * Return seller struct for publisher domain
   */
  function getSellerForPublisherDomain(string publisherDomain, string sellerDomain, string sellerId) external constant returns (string, string, uint, string) {
    address publisher = domainPublisher[sha3(publisherDomain)];

    bytes32 hash = sha3(sellerDomain, sellerId);
    Seller storage seller = sellers[publisher][hash];

    // TODO: better way
    uint rel = 0;

    if (seller.rel == Relationship.Reseller) {
      rel = 1;
    }

    return (seller.domain, seller.id, rel, seller.tagId);
  }
}