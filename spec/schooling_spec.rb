require 'schooling'

describe 'demo' do
  it 'should' do
    demo = Schooling::Demo.new
    expect(demo.hello_world).to eq(:hello_world)
  end
end
