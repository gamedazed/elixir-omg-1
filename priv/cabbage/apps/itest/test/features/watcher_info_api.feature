Feature: Watcher info

  Scenario: Alice want to use watcher info api
    When Alice deposits "1" ETH to the root chain creating 1 utxo
    Then Alice is able to paginate her UTXOs
