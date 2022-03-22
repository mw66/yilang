
all: yc

DUB=dub

yc: source/*.d
	$(DUB) -q build

TEST_DIR = test/rename_field
example:
	./yc -c $(TEST_DIR)/visitor.yi
	cd $(TEST_DIR) && dmd visitorApp.d visitor.d && ./visitorApp

clean:
	$(DUB) clean
	$(RM) -fr yc

# if needed to change account:
# git config --global -e
push:
	git config --global --list
	git push https://'yilabs'@github.com/yilabs/yilang.git
