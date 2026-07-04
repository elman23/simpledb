#!/usr/bin/env bash
#
# test_simpledb.sh
#
# A comprehensive test script for the 'simpledb' command-line utility.
# This script demonstrates:
#   - Basic command checks
#   - Proper handling of database directories and JSON tables
#   - Interaction with other UNIX utilities (grep, jq, join)
#   - Various use cases and edge cases
#
# Usage:
#   ./test_simpledb.sh
# Make sure 'simpledb' is compiled and available in $PATH or specify its location.

################################################################################
# Helpers and Setup
################################################################################

run() {
  "$@" 2> >(while IFS= read -r line; do
    echo -e "\e[31m$line\e[0m" >&2
  done)
}

# If your simpledb binary isn't in the PATH, set SIMPLEDB to the relative path.
# For example: SIMPLEDB=./simpledb
SIMPLEDB="${PWD}/../target/debug/simpledb"

# We create two test DB directories:
DB1="testdb1"
DB2="testdb2"
DB3="testdb3"

# Clean up any old directories from previous tests
rm -rf "$DB1" "$DB2" "$DB3"

# Create fresh directories
mkdir -p "$DB1"
mkdir -p "$DB2"
mkdir -p "$DB3"

echo -e "\e[32m=== Starting test of simpledb ===\e[0m"
echo -e "\e[32m=== Using three database directories: $DB1, $DB2 and $DB3 ===\e[0m"

################################################################################
# 1) Basic Usage / Error Handling
################################################################################

echo ""
echo -e "\e[32m### 1) Testing missing arguments or invalid usage...\e[0m"

echo "- Attempting to run without arguments (expect usage error):"
run $SIMPLEDB 2>&1 || true

echo "- Attempting to run with no --db-path (expect usage error):"
run $SIMPLEDB list users 2>&1 || true

echo "- Attempting to run with --db-path but no command (expect usage error):"
run $SIMPLEDB --db-path "$DB1" 2>&1 || true

echo "- Attempting an unknown command (expect error):"
run $SIMPLEDB --db-path "$DB1" unknowncmd mytable 2>&1 || true

################################################################################
# 2) Basic Create and List
################################################################################

echo ""
echo -e "\e[32m### 2) Creating and listing a simple table...\e[0m"

# Step 2a: 'list' a table that doesn't yet exist (should be empty/created).
echo "- Listing 'users' in $DB1 (should be empty JSON array):"
run $SIMPLEDB --db-path "$DB1" list users

echo "- Checking the content of $DB1/users.json (should exist after first command, or created empty)."
ls -l "$DB1"

################################################################################
# 3) Save / Update and then List
################################################################################

echo ""
echo -e "\e[32m### 3) Save new records and update existing ones...\e[0m"

echo "- Adding a new record with id=100 to 'users' in $DB1:"
run $SIMPLEDB --db-path "$DB1" save users id=100 name="John Doe" age=30 email=john@example.com

echo "- Listing 'users' again (should show John):"
run $SIMPLEDB --db-path "$DB1" list users

echo "- Updating record with id=100 (changing email):"
run $SIMPLEDB --db-path "$DB1" save users id=100 email=johndoe@newmail.com

echo "- Listing 'users' again (should show updated email):"
run $SIMPLEDB --db-path "$DB1" list users

echo "- Adding second record with id=200..."
run $SIMPLEDB --db-path "$DB1" save users id=200 name="Alice" age=28 email=alice@example.com

echo "- Listing 'users' to confirm the second record..."
run $SIMPLEDB --db-path "$DB1" list users

################################################################################
# 4) Get By Field
################################################################################

echo ""
echo -e "\e[32m### 4) Get by field value...\e[0m"

echo "- Getting users with id=100 (should return John):"
run $SIMPLEDB --db-path "$DB1" get users id=100

echo "- Getting users with email=alice@example.com (should return Alice):"
run $SIMPLEDB --db-path "$DB1" get users email=alice@example.com

echo "- Getting users with an unknown field (should return no records):"
run $SIMPLEDB --db-path "$DB1" get users id=9999

################################################################################
# 5) Delete
################################################################################

echo ""
echo -e "\e[32m### 5) Delete records...\e[0m"

echo "- Deleting user with id=200:"
run $SIMPLEDB --db-path "$DB1" delete users id=200

echo "- Listing users (should only have John now):"
run $SIMPLEDB --db-path "$DB1" list users

echo "- Trying to delete a non-existent user (id=9999) (should delete 0):"
run $SIMPLEDB --db-path "$DB1" delete users id=9999

echo "- Listing users again to confirm no change:"
run $SIMPLEDB --db-path "$DB1" list users

################################################################################
# 6) Multiple Tables in the Same DB
################################################################################

echo ""
echo -e "\e[32m### 6) Working with multiple tables within the same database...\e[0m"

echo "- Creating a 'products' table in $DB1..."
run $SIMPLEDB --db-path "$DB1" save products id=5001 name="Widget" price=19.99
run $SIMPLEDB --db-path "$DB1" save products id=5002 name="Gadget" price=29.99

echo "- Listing 'products':"
run $SIMPLEDB --db-path "$DB1" list products

echo "- We still have 'users' table too. Listing 'users' again to check everything is intact:"
run $SIMPLEDB --db-path "$DB1" list users

################################################################################
# 7) Second Database Directory (Simultaneously)
################################################################################

echo ""
echo -e "\e[32m### 7) Creating and using a second separate database directory ($DB2)...\e[0m"

echo "- Let's add a 'users' table in $DB2 with different data..."
run $SIMPLEDB --db-path "$DB2" save users id=999 name="Jane Doe" email=jane@example.com
run $SIMPLEDB --db-path "$DB2" list users

echo "- $DB1 and $DB2 are totally independent. Checking each directory's content:"
echo "Contents of $DB1:"
ls -l "$DB1"
echo "Contents of $DB2:"
ls -l "$DB2"

################################################################################
# 8) Using grep and jq for advanced filtering
################################################################################

echo ""
echo -e "\e[32m### 8) Combining simpledb with grep and jq...\e[0m"

echo "- Let's add a few more users to $DB1's 'users' table..."
run $SIMPLEDB --db-path "$DB1" save users id=101 name="Alpha Tester" email=alpha@example.com
run $SIMPLEDB --db-path "$DB1" save users id=102 name="Beta Tester" email=beta@example.com
echo "- Now listing all users in JSON lines format:"
run $SIMPLEDB --db-path "$DB1" list users

echo ""
echo -e "\e[32m#### 8a) Using grep to find user names containing 'Tester':\e[0m"
run $SIMPLEDB --db-path "$DB1" list users | grep '"name":"[^"]*Tester'

echo ""
echo -e "\e[32m#### 8b) Using jq to filter by email matching 'example.com':\e[0m"
run $SIMPLEDB --db-path "$DB1" list users | jq 'select(.email | test("example\\.com$"))'

echo ""
echo -e "\e[32m#### 8c) Sorting by name with jq:\e[0m"
run $SIMPLEDB --db-path "$DB1" list users | jq -s 'sort_by(.name)[]'

################################################################################
# 9) Simulating a JOIN using standard UNIX tools
################################################################################

echo ""
echo -e "\e[32m### 9) Simulating a 'join' between tables...\e[0m"

# We'll treat 'users' in $DB1 as a table with fields: id, name, email
# We'll create an 'orders' table with fields: order_id, user_id, product, price

echo "- Creating an 'orders' table in $DB1..."
run $SIMPLEDB --db-path "$DB1" save orders order_id=9001 user_id=100 product="Red Book" price=15.00
run $SIMPLEDB --db-path "$DB1" save orders order_id=9002 user_id=101 product="Blue Pen" price=2.50
run $SIMPLEDB --db-path "$DB1" save orders order_id=9003 user_id=999 product="Green Pencil" price=1.00
echo "- Listing 'orders':"
run $SIMPLEDB --db-path "$DB1" list orders

echo ""
echo -e "\e[32m#### 9a) Converting 'users' to CSV (id,name,email) => users.csv\e[0m"
run $SIMPLEDB --db-path "$DB1" list users | \
  jq -r '[.id, .name, .email] | @csv' > users.csv
cat users.csv

echo ""
echo -e "\e[32m#### 9b) Converting 'orders' to CSV (order_id,user_id,product,price) => orders.csv\e[0m"
run $SIMPLEDB --db-path "$DB1" list orders | \
  jq -r '[.order_id, .user_id, .product, .price] | @csv' > orders.csv
cat orders.csv

echo ""
echo -e "\e[32m#### 9c) Sort both CSV files by their key for join.\e[0m"
# For users.csv, the key is the first column (id).
# For orders.csv, the key is the second column (user_id), so we want to rearrange or join properly.
sort -t, -k1,1 users.csv > users_sorted.csv
sort -t, -k2,2 orders.csv > orders_sorted.csv

echo "- Sorted 'users':"
cat users_sorted.csv
echo "- Sorted 'orders':"
cat orders_sorted.csv

echo ""
echo -e "\e[32m#### 9d) Join by user_id (users.id == orders.user_id)\e[0m"
echo "(We have to specify that for 'users' the join field is column 1, for 'orders' it's column 2)"
join -t, -1 1 -2 2 users_sorted.csv orders_sorted.csv > joined.csv
echo "- Result of join (joined.csv):"
cat joined.csv

echo ""
echo -e "\e[32m#### 9e) Explanation:\e[0m"
echo "The joined.csv lines combine the user info with the order info if the IDs match."

################################################################################
# 10) Testing automatic ID generation and invalid ID values (in a new DB)
################################################################################

echo ""
echo -e "\e[32m### 10) Testing automatic and invalid IDs in $DB3...\e[0m"

echo "- Case A: Save without providing an ID at all (should auto-generate id=1)."
run $SIMPLEDB --db-path "$DB3" save people name="Bob" email="bob@example.com"

echo "- Listing 'people' (should see Bob with id=1):"
run $SIMPLEDB --db-path "$DB3" list people

echo ""
echo "- Case B: Save another record without ID (auto-generate id=2)."
run $SIMPLEDB --db-path "$DB3" save people name="Alice" email="alice@example.com"

echo "- Listing 'people' (should see Bob (id=1) and Alice (id=2)):"
run $SIMPLEDB --db-path "$DB3" list people

echo ""
echo "- Case C: Provide a valid positive integer ID."
run $SIMPLEDB --db-path "$DB3" save people id=10 name="Charlie" email="charlie@example.com"

echo "- Listing 'people' (should see Bob (id=1), Alice (id=2), and Charlie (id=10)):"
run $SIMPLEDB --db-path "$DB3" list people

echo ""
echo "- Case D: Provide an invalid (negative) ID, expecting an error."
run $SIMPLEDB --db-path "$DB3" save people id=-5 name="NegativeID" 2>&1 || true

echo "- Listing 'people' again (no changes expected):"
run $SIMPLEDB --db-path "$DB3" list people

echo ""
echo "- Case E: Provide an invalid (non-numeric) ID, expecting an error."
run $SIMPLEDB --db-path "$DB3" save people id=abc name="NonNumericID" 2>&1 || true

echo "- Listing 'people' again (no changes expected):"
run $SIMPLEDB --db-path "$DB3" list people

echo ""
echo -e "\e[32m### 10) End of tests for $DB3.\e[0m"

################################################################################
# 11) Final Checks
################################################################################

echo ""
echo -e "\e[32m### 11) Final checks and cleanup hints...\e[0m"

echo "- Database directories currently exist at $DB1, $DB2 and $DB3"
echo "- If you want to remove them, run: rm -rf $DB1 $DB2 $DB3"
echo "- CSV and JSON files (users.csv, orders.csv, etc.) are also in the current directory."


echo ""
echo -e "\e[32m=== End of test script for simpledb ===\e[0m"
exit 0

