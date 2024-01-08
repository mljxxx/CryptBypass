rm -rf ./DerivedData ./Payload ./Payload.tipa
xcodebuild build -project CryptBypass.xcodeproj -scheme CryptBypass -destination 'generic/platform=iOS' -sdk iphoneos -configuration Release -derivedDataPath DerivedData
mkdir ./Payload
cp -r ./DerivedData/Build/Products/Release-iphoneos/CryptBypass.app ./Payload/CryptBypass.app
ldid -Sentitlements.plist Payload/CryptBypass.app/CryptBypass
zip -r -q -o CryptBypass.tipa ./Payload