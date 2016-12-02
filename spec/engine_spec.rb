RSpec.describe Crawl::Engine do
  describe 'run' do
    context 'given a website' do
      let(:options) {
        {
          domain: 'https://www.example.com',
        }.merge(authentication)
      }

      context 'with a jwt token' do
        let(:authentication) {
          {
            auth_token: 'my_token'
          }
        }
        it 'makes a request using the provided token' do
          stub_request(:get, "https://www.example.com/").
            with(:headers => {'Authorization'=> 'my_token'}).
            to_return(:status => 200, :body => "", :headers => {})
          crawler = described_class.new(options)
          crawler.run
        end
      end

      context 'with a username and password' do
        let(:authentication) {
          {
            username: 'user',
            password: 'password'
          }
        }

        it 'makes a request with the correct credentials' do
          stub_request(:get, "https://www.example.com/").
            with(:headers => {'Authorization'=>['user', 'password']}).
            to_return(:status => 200, :body => "", :headers => {})
          crawler = described_class.new(options)
          crawler.run
        end
      end
    end
  end
end
