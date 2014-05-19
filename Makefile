PROJECT="TravisTest.xcodeproj"
TEST_TARGET="TravisTestTests"
SDK="iphoneos6.0"
CONFIGURATION="AdHoc"

CONFIGURATION_TEMP_DIR=./tmp
CONFIGURATION_BUILD_DIR=./bin
SIGN = "fNVvONEM9EvtGPTmMLKTQ5kMt8dBO21QHceSrmOCUB8muAy8QBsAtznxf5xlgUHp8P9a04y1NluypR29FZAByT3PX/v6GOya26+9FbsNnwtiBk4C2bQ8T1gBdO5T2+aKwXZhq6MiJjQ7umZGNrWp6lTHtmH+oDbJys5BjABkhSs="
ENCRYPTION_SECRET = "xbw1oBMWvF8GYLuCPdwBg+OaWNu7EAciUOjgygWXR4keFa5A5TRsdjNlhrlCAWkRr8WEJwZiTLxAbmelQDYfEc2PBFdLoVjQ73W5Yl9jb/NpRxv8H6eLA9KFAyLKY/d8hYqY/GjSxvIPfbZTHKBioOpj1N/zy9r9OVojHuw4RUQ="


APP_NAME=./bin/TravisTest.app
IPA_NAME=./bin/TravisTest.ipa
PROVISIONING_PROFILE=hogehoge.mobileprovision

DSYM_ZIP=./dsym
DSYM=./dsym

TF_APITOKEN=d03ef80732b5289ac66965637aa4401b_MTg1NDgwODIwMTQtMDUtMTYgMDg6MDE6MzMuOTIyMDU1
TF_TEAMTOKEN=e0f3de99de80c9a1d1547f0a1f6df50d_MzgxMzkyMjAxNC0wNS0xOSAwMTo1NTozNy4zMDY4MTM

clean:
	xcodebuild -project $(PROJECT) clean

# build - AdHoc ビルドをおこなう
build: add-certificates
	echo build
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIGURATION) \
		CODE_SIGN_IDENTITY=$(SIGN) CONFIGURATION_TEMP_DIR=$(CONFIGURATION_TEMP_DIR) CONFIGURATION_BUILD_DIR=$(CONFIGURATION_BUILD_DIR) \
		clean build
 
# add-certificates - KeyChain を作成する
add-certificates: decrypt-certificates
	echo add-certificates
	security create-keychain -p travis ios-build.keychain
	security import ./scripts/certs/AppleWWDRCA.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
	security import ./scripts/certs/dist.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
	security import ./scripts/certs/dist.p12 -k ~/Library/Keychains/ios-build.keychain -P $(ENCRYPTION_SECRET) -T /usr/bin/codesign
	security default-keychain -s ~/Library/Keychains/ios-build.keychain
	mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
	cp ./scripts/certs/$(PROVISIONING_PROFILE) ~/Library/MobileDevice/Provisioning\ Profiles/
 
# decrypt_certificates - 暗号化されたファイルを復号化する
decrypt-certificates:
	echo decrypt-certificates
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/certs/$(PROVISIONING_PROFILE).enc -d -a -out scripts/certs/$(PROVISIONING_PROFILE)
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/certs/dist.p12.enc -d -a -out scripts/certs/dist.p12
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/certs/dist.p12.enc -d -a -out scripts/certs/dist.p12


# archive - IPA ファイルを生成する
archive: build
	xcrun \
		-sdk $(SDK) \
		PackageApplication $(APP_NAME) \
		-o $(IPA_NAME) \
		-embed ~/Library/MobileDevice/Provisioning\ Profiles/$(PROVISIONING_PROFILE)

# zip-dsym - DSYM.zip ファイルを作成する
zip-dsym: build
	zip -r $(DSYM_ZIP) $(DSYM)

# testflight - IAP ファイルと DSYM ファイルを TestFlight へアップロードする
testflight: archive zip-dsym
	curl 'http://testflightapp.com/api/builds.json' \
		-F 'file=@$(IPA_NAME)' \
		-F 'dsym=@$(DSYM_ZIP)' \
		-F 'api_token=$(TF_APITOKEN)' \
		-F 'team_token=$(TF_TEAMTOKEN)' \
		-F 'notes=This build was uploaded via the upload API on the Travis CI' \
		-v