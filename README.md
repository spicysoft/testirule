# TestiRule

TestiRule は [landro/TesTcl](https://github.com/landro/TesTcl) を fork して rename したリポジトリです。
目的は、F5 BIG-IP iRule のテストを実案件の保守作業で使いやすい形に整備することです。

元の TesTcl は、iRule を Tcl でユニットテストするための土台を提供していました。
このリポジトリではその土台を維持しつつ、Docker 実行、CI、BIG-IP 向けモック、AS3 context、
参照整合性チェック、サンプルスイートを追加し、より直接的に iRule テストハーネスとして使えるようにしています。

## Fork & Rename

このリポジトリは TesTcl を fork し、目的が伝わるように TestiRule へ rename しました。
単なる Tcl テスト補助ライブラリではなく、F5 BIG-IP iRule 保守のためのテストハーネスであることを
名前から分かるようにするためです。

rename は名称変更だけではなく、重視する対象の違いも表しています。

- upstream TesTcl: 汎用的な iRule ユニットテストの基盤
- this fork / TestiRule: チームで iRule テストを実行・検証・保守するための実務向けワークフロー

つまり TestiRule は、TesTcl の書き方や考え方を可能な範囲で引き継ぎつつ、
ローカル開発や CI で再現性よく iRule テストを回すための機能を追加した fork です。

## このリポジトリで改善した点

この fork では、TesTcl をそのまま使うだけでは不足していた実務向け機能を追加しています。

- Docker 実行環境
  - ローカル PC に Tcl を直接入れなくても `docker compose run --rm test` でテストを実行できます。
- GitHub Actions 対応
  - push / pull request で自動テストを流し、失敗時は CI を失敗させられます。
- テスト失敗時の非ゼロ終了
  - 標準出力だけでなく終了コードでも失敗を検知できるため、CI 連携が安定します。
- Data Group / `class` モック
  - `class match`、`class lookup`、`class exists` を使う iRule をテストできます。
- `IP::addr` / CIDR 判定
  - `IP::client_addr` を使った IPv4 単一 IP / CIDR 判定をテストできます。
- `virtual` と default pool / effective route
  - `virtual` 転送、default pool、最終的な routing 結果を検証できます。
- AS3 context 抽出
  - AS3 JSON から test context を抽出し、default pool や iRule 紐付けをテスト前提として扱えます。
- AS3/iRule 参照整合性チェック
  - iRule が参照する pool / virtual / Data Group と AS3 上の定義の不整合を事前に検出できます。
- 実用サンプルテストスイート
  - iRule・テスト・AS3・validation をまとめたサンプル一式から使い方を把握できます。

## 改善された機能の使い方

最初は Docker で通常テストを流すのが一番分かりやすい使い方です。

```bash
docker compose build
docker compose run --rm test
```

サンプルテストスイートも通常テスト実行に含まれています。
追加したサンプルは `examples/irules/` と `test/test_sample_suite_it.tcl` にまとまっています。

Data Group、`IP::addr`、`virtual`、default pool を使うテストは、次のサンプルから読むと流れを把握しやすいです。

- `examples/irules/host_datagroup_routing.tcl`
- `examples/irules/uri_to_pool_map.tcl`
- `examples/irules/access_control_by_ip.tcl`
- `examples/irules/internal_network_datagroup.tcl`
- `examples/irules/virtual_routing.tcl`
- `examples/irules/maintenance_response.tcl`

AS3 context を抽出する場合は次のコマンドを使います。

```bash
python3 tools/extract-as3-context.py \
  examples/as3/app-web.json \
  --output examples/as3/app-web.context.json
```

Docker 経由でも同じように実行できます。

```bash
docker compose run --rm test python3 tools/extract-as3-context.py \
  examples/as3/app-web.json \
  --output examples/as3/app-web.context.json
```

AS3/iRule の参照整合性を確認する場合は次のコマンドです。

```bash
python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irules-dir examples/irules
```

broken サンプルで非ゼロ終了を確認したい場合は、失敗確認用の iRule を個別に指定します。

```bash
python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irule examples/broken-irules/broken_missing_pool.tcl
```

```bash
python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irule examples/broken-irules/broken_missing_datagroup.tcl
```

通常運用では成功サンプルだけを CI に載せ、broken sample は手動の失敗確認用として分離して使います。

## よく使う実行コマンド

- 通常テスト: `docker compose run --rm test`
- 単一 Tcl テスト: `docker compose run --rm test test/<file>.tcl`
- AS3 context 抽出: `docker compose run --rm test python3 tools/extract-as3-context.py ...`
- AS3/iRule validation: `docker compose run --rm test python3 tools/validate-as3-irule-links.py ...`

## 詳細機能

### upstream TesTcl のリリース履歴

- 4th May 2020 - Version [1.0.14](https://github.com/landro/TesTcl/releases) released
- 10th November 2018 - Version [1.0.13](https://github.com/landro/TesTcl/releases) released
- 26th September 2018 - Version [1.0.12](https://github.com/landro/TesTcl/releases) released
- 24th May 2018 - Version [1.0.11](https://github.com/landro/TesTcl/releases) released
- 23rd March 2017 - Version [1.0.10](https://github.com/landro/TesTcl/releases) released
- 29th April 2016 - Version [1.0.9](https://github.com/landro/TesTcl/releases) released

## Getting started

### Run tests with Docker

You can run TesTcl/TestiRule tests without installing Tcl on your local machine.
The Docker image includes the required runtime dependencies:

- `tcl`
- `tcllib`
- `bash`

The container entrypoint is `scripts/run-tests.sh`.
It exports `TCLLIBPATH`, prefers the existing `test/test_*.tcl` suite, and falls back to
`examples/test_minimal_irule.tcl` if no existing suite is present.

Build and run with Docker Compose:

```bash
docker compose build
docker compose run --rm test
```

Or build and run the image directly:

```bash
docker build -t testirule .
docker run --rm testirule
```

You can also target a specific test file through the container entrypoint:

```bash
docker compose run --rm test examples/test_minimal_failure.tcl
```

Check the process exit code after running tests:

Successful run:

```bash
docker compose run --rm test
echo $?
```

Expected exit code:

```text
0
```

Failing run:

```bash
docker compose run --rm test examples/test_minimal_failure.tcl
echo $?
```

Expected exit code:

```text
1
```

### Run tests with GitHub Actions

Automatic tests run on GitHub Actions for:

- push to `main` or `master`
- pull requests targeting `main` or `master`

The workflow builds the Docker test image and runs:

```bash
docker compose run --rm test
```

Because the container entrypoint propagates the test process exit code, the GitHub Actions
job succeeds on passing tests and fails on test errors.

### Mock Data Groups

TestiRule can define test Data Groups directly in Tcl and use them through `class`.

Record-only groups:

```tcl
datagroup_create allowed_hosts string {
  "example.com"
  "api.example.com"
}
```

Key/value groups for `class lookup`:

```tcl
datagroup_map uri_to_pool_map string {
  "/api" "api_pool"
  "/admin" "admin_pool"
}
```

Address groups accept IPv4 addresses and CIDR ranges:

```tcl
datagroup_create internal_networks address {
  "10.0.0.0/8"
  "192.168.0.0/16"
}
```

Supported `class` operations:

- `class match <value> equals <datagroup>`
- `class match <value> eq <datagroup>`
- `class match <value> starts-with <datagroup>`
- `class match <value> starts_with <datagroup>`
- `class match <value> ends-with <datagroup>`
- `class match <value> contains <datagroup>`
- `class lookup <key> <datagroup>`
- `class exists <datagroup>`

Match direction is defined as follows:

- `starts-with`: `<value>` starts with any Data Group record
- `ends-with`: `<value>` ends with any Data Group record
- `contains`: `<value>` contains any Data Group record

For `address` Data Groups, this release only supports the minimum needed for `class match ... equals ...`
with IPv4 addresses and CIDR records. Full `IP::addr` behavior remains out of scope.

### Mock IP::addr

TestiRule supports the minimum IPv4 subset needed for common iRule tests:

```tcl
IP::addr 10.1.2.3 equals 10.0.0.0/8
IP::addr 10.1.2.3 equals 10.1.2.3
IP::addr [IP::client_addr] equals 10.0.0.0/8
IP::addr 10.1.2.3 == 10.0.0.0/8
```

Set the client IP in tests with:

```tcl
set_client_addr "10.1.2.3"
```

`IP::client_addr` and `IP::remote_addr` will both return that value unless an `on ... return ...`
expectation is defined for the same command.

Current scope:

- IPv4 single-address equality
- IPv4 CIDR inclusion checks
- invalid IP and invalid CIDR raise Tcl errors

Out of scope in this release:

- IPv6
- route domain suffixed addresses such as `10.0.0.1%1`
- netmask syntax such as `10.0.0.0/255.0.0.0`
- `IP::addr ... mask ...`
- full BIG-IP `IP::addr` compatibility

### Mock virtual

TestiRule can verify `virtual` as an endstate in the same style as `pool`:

```tcl
endstate virtual /Common/legacy_vs
```

Supported forms:

```tcl
virtual /Common/legacy_vs
virtual legacy_vs
```

Current behavior:

- `virtual <name>` records `virtual <name>` as the final action
- TestiRule keeps the existing terminal-command behavior already used by `pool`
- the first transfer command that hits the expected endstate stops evaluation for that event

Examples:

```tcl
pool /Common/api_pool
virtual /Common/legacy_vs
```

Final action:

```text
pool /Common/api_pool
```

```tcl
virtual /Common/legacy_vs
pool /Common/api_pool
```

Final action:

```text
virtual /Common/legacy_vs
```

This release does not attempt to re-run another virtual server's iRule chain.

### Default pool and effective route

TestiRule can model a virtual server default pool in test context:

```tcl
set_default_pool "/Common/web_pool"
```

After running an iRule, you can inspect the effective routing result:

```tcl
verify "effective pool" "/Common/web_pool" eq { effective_pool }
verify "effective action" {pool /Common/web_pool} eq { effective_action }
```

Behavior in this release:

- if no explicit final action is taken, `effective_pool` falls back to the configured default pool
- if `pool` is called, `effective_pool` becomes that explicit pool
- if `virtual`, `HTTP::redirect`, `HTTP::respond`, `reject`, or `drop` is called, `effective_action` reports that action
- `effective_pool` is empty for non-pool final actions

Current priority model:

- TestiRule keeps the existing terminal-command behavior used by current endstate handling
- the first transfer or terminal action that exits the event becomes the final action
- if no explicit action occurs and a default pool is configured, the effective action is `pool <default-pool>`
- if no explicit action occurs and no default pool is configured, effective route is unset

### AS3 context extraction

TestiRule can extract test context from an AS3 declaration so iRule tests can reuse the same
default pool, attached iRules, pools, and Data Group names defined in AS3.

Run the extractor directly:

```bash
python3 tools/extract-as3-context.py examples/as3/app-web.json
```

Write the result to a file:

```bash
python3 tools/extract-as3-context.py examples/as3/app-web.json --output test-context/app-web.context.json
```

Run it through Docker:

```bash
docker compose run --rm test python3 tools/extract-as3-context.py examples/as3/app-web.json
```

The extractor currently walks:

- `Tenant`
- `Application`
- `Service_HTTP`
- `Service_HTTPS`
- `Service_TCP`
- `Service_UDP`
- `Service_L4`
- `Pool`
- `iRule`
- `Data_Group`
- `Data_Group_String`
- `Data_Group_Integer`
- `Data_Group_Address`

Supported reference forms in `pool` and `iRules`:

- plain string such as `"web_pool"`
- AS3 `use` reference such as `{ "use": "web_pool" }`

Out of scope in this release:

- AS3/iRule reference validation
- full AS3 schema validation
- AS3 deploy
- AS3 class coverage beyond the list above
- iRule Tcl parsing

`#9` is expected to handle AS3/iRule reference consistency checks later.

### AS3/iRule reference validation

TestiRule can validate whether references inside iRule files match the AS3-derived test context.
This catches missing pools, unresolved Data Groups, broken attached iRule definitions, and missing
iRule files before deployment.

Validate every Tcl file in a directory:

```bash
python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irules-dir examples/irules
```

Validate a single iRule file:

```bash
python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irule examples/irules/route_by_uri.tcl
```

Run it through Docker:

```bash
docker compose run --rm test python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irules-dir examples/irules
```

Optional flags:

- `--strict`: treat warnings as a failure
- `--json`: emit machine-readable validation results

Current checks:

- `pool <name>`
- `virtual <name>`
- `class match ... <datagroup>`
- `class lookup ... <datagroup>`
- `class exists <datagroup>`
- service `attachedIRules`
- AS3 iRule definitions versus repository files

Current path resolution rules:

- `/Tenant/App/Object`: validated as an exact AS3 context path
- `/Common/...` pool: must exist as the same full path in context
- `/Common/...` virtual: warning only, because AS3 context alone cannot prove the external target
- relative names such as `api_pool`: resolved against the owning AS3 application when the iRule file name maps to a known AS3 iRule
- dynamic references such as `pool $target_pool`: warning only, or failure with `--strict`

Example success output:

```text
OK: AS3/iRule references are valid.
Checked:
- pools: 2
- virtuals: 0
- data groups: 1
- iRules: 1
```

Out of scope in this release:

- full Tcl parsing
- full static analysis of dynamically generated names
- AS3 schema validation
- deploy to BIG-IP

### Sample iRule test suite

TestiRule now includes a practical sample suite under `examples/` so new users can see how
to combine iRule code, Tcl tests, AS3 context extraction, and AS3/iRule reference validation.

Sample layout:

- `examples/irules/`: success-path sample iRules used by validation and tests
- `examples/broken-irules/`: failure samples for manual validation checks
- `examples/as3/app-web.json`: AS3 declaration covering the sample application
- `examples/as3/app-web.context.json`: extracted context for the same declaration
- `test/test_sample_suite_it.tcl`: Tcl integration tests that exercise the samples

Included samples:

- `route_by_uri.tcl`: URI-based pool selection with default pool fallback
- `host_datagroup_routing.tcl`: host-based routing with a string Data Group
- `uri_to_pool_map.tcl`: Data Group lookup returning a pool path
- `access_control_by_ip.tcl`: `IP::addr` CIDR-based internal/external routing
- `internal_network_datagroup.tcl`: address Data Group matching
- `virtual_routing.tcl`: `virtual` forwarding to another service
- `maintenance_response.tcl`: `HTTP::respond` taking priority over default routing

Run the normal sample suite through the standard test entrypoint:

```bash
docker compose run --rm test
```

Regenerate AS3 context for the samples:

```bash
docker compose run --rm test python3 tools/extract-as3-context.py \
  examples/as3/app-web.json \
  --output examples/as3/app-web.context.json
```

Validate references for the success samples:

```bash
docker compose run --rm test python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irules-dir examples/irules
```

The validation suite includes `uri_to_pool_map.tcl`, which uses a dynamic `pool $target_pool`
reference after `class lookup`. That is expected to produce a warning in normal mode and a
non-zero exit only with `--strict`.

Failure samples are intentionally excluded from the normal test run and GitHub Actions. Run them
manually when you want to confirm non-zero exits:

```bash
docker compose run --rm test python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irule examples/broken-irules/broken_missing_pool.tcl
```

```bash
docker compose run --rm test python3 tools/validate-as3-irule-links.py \
  --context examples/as3/app-web.context.json \
  --irule examples/broken-irules/broken_missing_datagroup.tcl
```

This sample suite is meant to demonstrate maintainable iRule test patterns, not to fully emulate
BIG-IP runtime behavior.

## 旧 TesTcl リファレンス

If you're familiar with unit testing and [mocking](http://en.wikipedia.org/wiki/Mock_object) in particular,
using TesTcl should't be to hard. Check out the examples below:

### Simple example

Let's say you want to test the following simple iRule found in *simple_irule.tcl*:

```tcl
rule simple {

  when HTTP_REQUEST {
    if { [HTTP::uri] starts_with "/foo" } {
      pool foo
    } else {
      pool bar
    }
  }

  when HTTP_RESPONSE {
    HTTP::header remove "Vary"
    HTTP::header insert Vary "Accept-Encoding"
  }

}
```

Now, create a file called *test_simple_irule.tcl* containing the following lines:

```tcl
package require -exact testcl 1.0.14
namespace import ::testcl::*

# Comment in to enable logging
#log::lvSuppressLE info 0

it "should handle request using pool bar" {
  event HTTP_REQUEST
  on HTTP::uri return "/bar"
  endstate pool bar
  run simple_irule.tcl simple
}

it "should handle request using pool foo" {
  event HTTP_REQUEST
  on HTTP::uri return "/foo/admin"
  endstate pool foo
  run simple_irule.tcl simple
}

it "should replace existing Vary http response headers with Accept-Encoding value" {
  event HTTP_RESPONSE
  verify "there should be only one Vary header" 1 == {HTTP::header count vary}
  verify "there should be Accept-Encoding value in Vary header" "Accept-Encoding" eq {HTTP::header Vary}
  HTTP::header insert Vary "dummy value"
  HTTP::header insert Vary "another dummy value"
  run simple_irule.tcl simple
}
```

#### Installing JTcl including jtcl-irule extensions

##### Install JTcl
Download [JTcl](https://jtcl-project.github.io/jtcl/), unzip it and add it to your path.

##### Add jtcl-irule to your JTcl installation
Add the [jtcl-irule](http://landro.github.io/jtcl-irule/) extension to JTcl. If you don't have the time to build it yourself, you can download the 
jar artifact from the [release v 0.9](https://github.com/landro/jtcl-irule/releases/tag/v0.9) page or you can use the direct [link](https://github.com/landro/jtcl-irule/releases/download/v0.9/jtcl-irule-0.9.jar).
Next, copy the jar file into the directory where you installed JTcl.
Add jtcl-irule to the classpath in _jtcl_ or _jtcl.bat_.
**IMPORTANT!** Make sure you place the _jtcl-irule-0.9.jar_ on the classpath **before** the standard jtcl-<version>.jar

###### MacOS X and Linux

On MacOs X and Linux, this can be achieved by putting the following line just above the last line in the jtcl shell script

    export CLASSPATH=$dir/jtcl-irule-0.9.jar:$CLASSPATH
    
###### Windows

On Windows, modify the following line in jtcl.bat from 

    set cp="%dir%\jtcl-%jtclver%.jar;%CLASSPATH%"

to

    set cp="%dir%\jtcl-irule-0.9.jar;%dir%\jtcl-%jtclver%.jar;%CLASSPATH%"

##### Verify installation

Create a script file named *test_jtcl_irule.tcl* containing the following lines 

```tcl
if {"aa" starts_with "a"} {
  puts "The jtcl-irule extension has successfully been installed"
}
```

and execute it using 

    jtcl test_jtcl_irule.tcl

You should get a success message. 
If you get a message saying *syntax error in expression ""aa" starts_with "a"": variable references require preceding $*, jtcl-irule is not on the classpath **before** the standard jtcl-<version>.jar. Please review instructions above.

##### Add the testcl library to your library path
Download latest [TesTcl distribution](https://github.com/landro/TesTcl/releases) from github containing all the files (including examples) found in the project.
Unzip, and add unzipped directory to the [TCLLIBPATH](http://jtcl.kenai.com/gettingstarted.html) environment variable:

On MacOS X and Linux:

    export TCLLIBPATH=whereever/TesTcl-1.0.14
    
On Windows, create a System Variable named `TCLLIBPATH` and make sure that the path uses forward slashes '/'

In order to run this example, type in the following at the command-line:

    >jtcl test_simple_irule.tcl

This should give you the following output:

    **************************************************************************
    * it should handle request using pool bar
    **************************************************************************
    -> Test ok

    **************************************************************************
    * it should handle request using pool foo
    **************************************************************************
    -> Test ok

    **************************************************************************
    * it should replace existing Vary http response headers with Accept-Encoding value
    **************************************************************************
    verification of 'there should be only one Vary header' done.
    verification of 'there should be Accept-Encoding value in Vary header' done.
    -> Test ok

#### Explanations

- Require the **testcl** package and import the commands and variables found in the **testcl** namespace to use it.
- Enable or disable logging
- Add the specification tests
  - Describe every _it_ statement as precisely as possible. It serves as documentation.
  - Add an _event_ . **This is mandatory.**
  - Add one or several _on_ statements to setup expectations/mocks. If you don't care about the return value, return "".
  - Add an _endstate_. This could be a _pool_, _HTTP::respond_, _HTTP::redirect_ or any other function call (see [link](https://devcentral.f5.com/tech-tips/articles/-the101-irules-101-routing#.UW0OwoLfeN4)).
  - Add a _verify_. The verifications will be run immediately after the iRule execution. Describe every verification as precisely as possible, add as many *verification*s as needed in your particular test scenario.
  - Add an HTTP::header initialization if you are testing modification of HTTP headers (stubs/mocks are provided for all commands in HTTP namespace).
  - Add a _run_ statement in order to actually run the Tcl script file containing your iRule. **This is mandatory.**

##### A word on the TesTcl commands #####

- _it_ statement takes two arguments, description and code block to execute as test case.
- _event_ statement takes a single argument - event type. Supported values are [all standard HTTP, TCP and IP events .](https://devcentral.f5.com/wiki/irules.Events.ashx)
- _on_ statement has the following syntax: _on_ ... (return|error) result
- _endstate_ statement accepts 2 to 5 arguments which are matched with command to stop processing iRule with success in test case evaluation.
- _verify_ statement takes four arguments. Syntax: _verify_ "DESCRIPTION" value _CONDITION_ {verification code}
  - _description_ is displayed during verification execution
  - _value_ is expected result of verification code
  - _condition_ is operator used during comparison of _value_ with code result (ex. ==, !=, eq).
  - _verification_code_ is code to evaluate after iRule execution
- _run_ statement takes two arguments, file name of iRule source and name of iRule to execute

##### A word on stubs or mockups (you choose what to call 'em)#####

###### HTTP namespace ######
Most of the other commands in the HTTP namespace have been implemented. We've done our best, but might have missed some details. Look at the sourcecode if 
you wonder what is going on in the mocks.
In particular, the [HTTP::header](https://devcentral.f5.com/wiki/irules.HTTP__header.ashx) mockup implementation should work as expected.
However _insert_modssl_fields_ subcommand is not supported in current version.

###### URI namespace ######
Everything should be supported, with the exception of:

 - [URI::encode](https://devcentral.f5.com/wiki/iRules.URI__encode.ashx)
 - [URI::decode](https://devcentral.f5.com/wiki/iRules.URI__decode.ashx)

which is only partially supported.

###### GLOBAL namespace ######
Support for

 - [getfield](https://devcentral.f5.com/wiki/iRules.getfield.ashx)
 - [log](https://devcentral.f5.com/wiki/iRules.log.ashx) 

#### Avoiding code duplication using the before command

In order to avoid code duplication, one can use the _before_ command.
The argument passed to the _before_ command will be executed _before_ the following _it_ specifications.

NB! Be carefull with using _on_ commands in _before_. If there will be another definition of the same expectation in _it_ statement, only first one will be in use (this one set in _before_).

Using the _before_ command, *test_simple_irule.tcl* can be rewritten as:

```tcl
package require -exact testcl 1.0.14
namespace import ::testcl::*

# Comment in to enable logging
#log::lvSuppressLE info 0

before {
  event HTTP_REQUEST
}

it "should handle request using pool bar" {
  on HTTP::uri return "/bar"
  endstate pool bar
  run simple_irule.tcl simple
}

it "should handle request using pool foo" {
  on HTTP::uri return "/foo/admin"
  endstate pool foo
  run simple_irule.tcl simple
}

it "should replace existing Vary http response headers with Accept-Encoding value" {
  # NB! override event type set in before
  event HTTP_RESPONSE

  verify "there should be only one Vary header" 1 == {HTTP::header count vary}
  verify "there should be Accept-Encoding value in Vary header" "Accept-Encoding" eq {HTTP::header Vary}
  HTTP::header insert Vary "dummy value"
  HTTP::header insert Vary "another dummy value"
  run irules/simple_irule.tcl simple
}
```

On a side note, it's worth mentioning that there is no _after_ command, since we're always dealing with mocks.

### Advanced example

Let's have a look at a more advanced iRule (advanced_irule.tcl):

```tcl
rule advanced {

  when HTTP_REQUEST {

    HTTP::header insert X-Forwarded-SSL true

    if { [HTTP::uri] eq "/admin" } {
      if { ([HTTP::username] eq "admin") && ([HTTP::password] eq "password") } {
        set newuri [string map {/admin/ /} [HTTP::uri]]
        HTTP::uri $newuri
        pool pool_admin_application
      } else {
        HTTP::respond 401 WWW-Authenticate "Basic realm=\"Restricted Area\""
      }
    } elseif { [HTTP::uri] eq "/blocked" } {
      HTTP::respond 403
    } elseif { [HTTP::uri] starts_with "/app"} {
      if { [active_members pool_application] == 0 } {
        if { [HTTP::header User-Agent] eq "Apache HTTP Client" } {
          HTTP::respond 503
        } else {
          HTTP::redirect "http://fallback.com"
        }
      } else {
        set newuri [string map {/app/ /} [HTTP::uri]]
        HTTP::uri $newuri
        pool pool_application
      }
    } else {
      HTTP::respond 404
    }

  }

}
```

The specs for this iRule would look like this:

```tcl
package require -exact testcl 1.0.14
namespace import ::testcl::*

# Comment out to suppress logging
#log::lvSuppressLE info 0

before {
  event HTTP_REQUEST
}

it "should handle admin request using pool admin when credentials are valid" {
  HTTP::uri "/admin"
  on HTTP::username return "admin"
  on HTTP::password return "password"
  endstate pool pool_admin_application
  run irules/advanced_irule.tcl advanced
}

it "should ask for credentials when admin request with incorrect credentials" {
  HTTP::uri "/admin"
  HTTP::header insert Authorization "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=="
  verify "user Aladdin" "Aladdin" eq {HTTP::username}
  verify "password 'open sesame'" "open sesame" eq {HTTP::password}
  verify "WWW-Authenticate header is 'Basic realm=\"Restricted Area\"'" "Basic realm=\"Restricted Area\"" eq {HTTP::header "WWW-Authenticate"}
  verify "response status code is 401" 401 eq {HTTP::status}
  run irules/advanced_irule.tcl advanced
}

it "should ask for credentials when admin request without credentials" {
  HTTP::uri "/admin"
  verify "WWW-Authenticate header is 'Basic realm=\"Restricted Area\"'" "Basic realm=\"Restricted Area\"" eq {HTTP::header "WWW-Authenticate"}
  verify "response status code is 401" 401 eq {HTTP::status}
  run irules/advanced_irule.tcl advanced
}

it "should block access to uri /blocked" {
  HTTP::uri "/blocked"
  endstate HTTP::respond 403
  run irules/advanced_irule.tcl advanced
}

it "should give apache http client a correct error code when app pool is down" {
  HTTP::uri "/app"
  on active_members pool_application return 0
  HTTP::header insert User-Agent "Apache HTTP Client"
  endstate HTTP::respond 503
  run irules/advanced_irule.tcl advanced
}

it "should give other clients then apache http client redirect to fallback when app pool is down" {
  HTTP::uri "/app"
  on active_members pool_application return 0
  HTTP::header insert User-Agent "Firefox 13.0.1"
  verify "response status code is 302" 302 eq {HTTP::status}
  verify "Location header is 'http://fallback.com'" "http://fallback.com" eq {HTTP::header Location}
  run irules/advanced_irule.tcl advanced
}

it "should give handle app request using app pool when app pool is up" {
  HTTP::uri "/app/form?test=query"
  on active_members pool_application return 2
  endstate pool pool_application
  verify "result uri is /form?test=query" "/form?test=query" eq {HTTP::uri}
  verify "result path is /form" "/form" eq {HTTP::path}
  verify "result query is test=query" "test=query" eq {HTTP::query}
  run irules/advanced_irule.tcl advanced
}

it "should give 404 when request cannot be handled" {
  HTTP::uri "/cannot_be_handled"
  endstate HTTP::respond 404
  run irules/advanced_irule.tcl advanced
}

stats
```

### Modification of HTTP headers example

Let's have a look at another iRule (headers_irule.tcl):

```tcl    
rule headers {

  #notify backend about SSL using X-Forwarded-SSL http header
  #if there is client certificate put common name into X-Common-Name-SSL http header
  #if not make sure X-Common-Name-SSL header is not set
  when HTTP_REQUEST {
    HTTP::header insert X-Forwarded-SSL true
    HTTP::header remove X-Common-Name-SSL
    
    if { [SSL::cert count] > 0 } {
      set ssl_cert [SSL::cert 0]
      set subject [X509::subject $ssl_cert]
      set cn ""
      foreach { label value } [split $subject ",="] {
        set label [string toupper [string trim $label]]
        set value [string trim $value]
        
        if { $label == "CN" } {
          set cn "$value"
          break
        }
      }
    
      HTTP::header insert X-Common-Name-SSL "$cn"
    }
  }

}
```

The example specs for this iRule would look like this:

```tcl
package require -exact testcl 1.0.14
namespace import ::testcl::*

# Comment out to suppress logging
#log::lvSuppressLE info 0

before {
  event HTTP_REQUEST
  verify "There should be always set HTTP header X-Forwarded-SSL to true" true eq {HTTP::header X-Forwarded-SSL}
}

it "should remove X-Common-Name-SSL header from request if there was no client SSL certificate" {
  HTTP::header insert X-Common-Name-SSL "testCommonName"
  on SSL::cert count return 0
  verify "There should be no X-Common-Name-SSL" 0 == {HTTP::header exists X-Common-Name-SSL}
  run irules/headers_irule.tcl headers
}

it "should add X-Common-Name-SSL with Common Name from client SSL certificate if it was available" {
  on SSL::cert count return 1
  on SSL::cert 0 return {}
  on X509::subject [SSL::cert 0] return "CN=testCommonName,DN=abc.de.fg"
  verify "X-Common-Name-SSL HTTP header value is the same as CN" "testCommonName" eq {HTTP::header X-Common-Name-SSL}
  run irules/headers_irule.tcl headers
}
```

### Classes Example

TesTcl has partial support for the `class` command. For example, we could test the following rule:

```tcl
rule classes {
  when HTTP_REQUEST {
    if { [class match [IP::remote_addr] eq blacklist] } {
      drop
    } else {
      pool main-pool
    }
  }
}
```

with code that looks like this

```tcl
package require -exact testcl 1.0.14
namespace import testcl::*

before {
  event HTTP_REQUEST
  class configure blacklist {
    "192.168.6.66" "blacklisted"
  }
}

it "should drop blacklisted addresses" {
  on IP::remote_addr return "192.168.6.66"
  endstate drop
  run irules/classes.tcl classes
}

it "should not drop addresses that are not blacklisted" {
  on IP::remote_addr return "192.168.0.1"
  endstate pool main-pool
  run irules/classes.tcl classes
}
```

## How stable is this code?
This work is quite stable, but you can expect minor breaking changes.

## Why I created this project

Configuring BIG-IP devices is no trivial task, and typically falls in under a DevOps kind of role.
In order to make your system perform the best it can, you need:

- In-depth knowledge about the BIG-IP system (typically requiring at least a [$2,000 3-day course](https://f5.com/education/training))
- In-depth knowledge about the web application being load balanced 
- The Tcl language and the iRule extensions
- And finally: _A way to test your iRules_

Most shops test iRules [manually](http://en.wikipedia.org/wiki/Manual_testing), the procedure typically being a variation of the following:

- Create/edit iRule
- Add log statements that show execution path
- Push iRule to staging/QA environment
- Bring backend servers up and down **manually** as required to test fallback scenarios
- Generate HTTP-traffic using a browser and verify **manually** everything works as expected
- Verify log entries **manually**
- Remove or disable log statements
- Push iRule to production environment
- Verify **manually** everything works as expected 

There are lots of issues with this **manual** approach:

- Using log statements for testing and debugging messes up your code, and you still have to look through the logs **manually**
- Potentially using different iRules in QA and production make automated deployment procedures harder
- Bringing servers up and down to test fallback scenarios can be quite tedious
- **Manual** verification steps are prone to error
- **Manual** testing takes a lot of time
- Development roundtrip-time is forever, since deployment to BIG-IP sometimes can take several minutes

Clearly, **manual** testing is not the way forward!

## Test matrix and compatibility

|               | Mac Os X | Windows| Cygwin |
| ------------- |----------|--------|--------|
| JTcl  2.4.0   | yes      | yes    | yes    |
| JTcl  2.5.0   | yes      | yes    | yes    |
| JTcl  2.6.0   | yes      | yes    | yes    |
| JTcl  2.7.0   | yes      | yes    | yes    |
| JTcl  2.8.0   | yes      | yes    | yes    |
| Tclsh 8.6     | yes*     | yes*   | ?      |

The * indicates support only for standard Tcl commands

If you use TesTcl on a different platform, please let us know

## Getting help

Post questions to the group at [TesTcl user group](https://groups.google.com/forum/?fromgroups#!forum/testcl-user)  
File bugs over at [github](https://github.com/landro/TesTcl)

## Contributing code

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Who uses it?

Well, I can't really tell you, but according to Google Analytics, this site gets around 10 hits per day.

## License

Just like JTcl, TesTcl is licensed under a BSD-style license. 

## Please please please

Drop me a line if you use this library and find it useful: stefan.landro **you know what** gmail.com

You can also check out [my LinkedIn profile](http://no.linkedin.com/in/landro) or 
[my Google+ profile](https://plus.google.com/114497086993236232709?rel=author), or 
even [my twitter account - follow it for TesTcl releases](https://twitter.com/landro)
