require 'cash_addr'

module CryptocoinPayable
  module Adapters
    class BitcoinCash < Bitcoin
      def self.coin_symbol
        'BCH'
      end

      def fetch_transactions(address)
        raise NetworkNotSupported if CryptocoinPayable.configuration.testnet

        url = "https://api.cryptoapis.io/v1/bc/bch/mainnet/address/#{legacy_address(address)}/transactions?index=0&limit=100"
        parse_block_explorer_transactions(get_request(url).body, address)
      end

      def create_address(id)
        CashAddr::Converter.to_cash_address(super)
      end

      def parse_block_explorer_transactions(response, address)
        json = JSON.parse(response)
        json['payload'].map { |tx| convert_block_cypher_transactions(tx, address) }
      rescue JSON::ParserError
        raise ApiError, response
      end

      def convert_block_cypher_transactions(transaction, address)
        {
          transaction_hash: transaction['txid'],
          block_hash: transaction['blockhash'],
          block_time: parse_time(transaction['blocktime']),
          estimated_time: parse_time(transaction['time']),
          estimated_value: parse_total_tx_value_block_cypher(transaction['txouts'], address),
          confirmations: transaction['confirmations'].to_i
        }
      end

      def parse_total_tx_value_block_cypher(output_transactions, address)
        output_transactions
          .map { |out| out['addresses'].join.eql?(address) ? (out['amount'].to_f * 100_000_000).to_i : 0 }
          .inject(:+) || 0
      end

      private

      def legacy_address(address)
        CashAddr::Converter.to_legacy_address(address)
      rescue CashAddr::InvalidAddress
        raise ApiError
      end

      def prefix
        CryptocoinPayable.configuration.testnet ? 'bchtest.' : 'bitcoincash.'
      end
    end
  end
end
