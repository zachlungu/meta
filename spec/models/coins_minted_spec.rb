require 'spec_helper'

describe CoinsMinted do
  let(:proposer) { User.make!(username: 'proposer') }
  let(:creator) { User.make!(username: 'creator') }
  let(:product) { Product.make!(user: creator) }
  let(:worker) { User.make! }
  let(:voter) { User.make! }
  let(:benefactor) { User.make!(username: 'benefactor') }


  context 'work on wip' do
    let(:work) { Task.make!(product: product, user: proposer) }
    let(:winning_event) { work.comments.make!(user: worker) }
    let(:award) { work.awards.make!(awarder: proposer, winner: worker, event: winning_event, wip: work) }

    it 'transfers coins based on tip contracts' do
      start_at = Time.now

      work.award!(proposer, winning_event)

      AutoTipContract.create!(product: product, user: product.user, amount: 0.025)
      AutoTipContract.create!(product: product, user: benefactor, amount: 0.020)


      entry = TransactionLogEntry.minted!(work.id, work.created_at, product, award.id, 10000)

      CoinsMinted.new.perform(entry.id)

      expect(
        TransactionLogEntry.credit.each_with_object({}){|e, h| h[e.wallet_id] = e.cents }
      ).to eq({
        product.user.id => (10000 * 0.025).to_i,  # auto tip contract
        benefactor.id   => (10000 * 0.020).to_i,  # auto tip contract
        proposer.id     => (10000 * 0.05).to_i,   # bounty author
        worker.id       => (10000 * 0.905).to_i   # bounty winner
      })

      expect(
        TransactionLogEntry.balance(product, work.id)
      ).to eq(0)
    end
  end
end
