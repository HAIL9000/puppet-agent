component "cfpropertylist" do |pkg, settings, platform|
  pkg.load_from_json('configs/components/cfpropertylist.json')

  pkg.build_requires "ruby"

  pkg.install do
    ["cp -pr lib/* #{settings[:ruby_vendordir]}"]
  end
end
