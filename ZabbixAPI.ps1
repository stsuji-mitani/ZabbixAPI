param(
    $authmode = "id"
    ,$id = ""
    ,$pass = ""
    ,$key = ""
)
# authmode : id 　　ID/Passwordによる認証
#          : static WebコンソールでAPIキーを発行して利用
# id       : 認証ID
# pass     : 認証パスワード
# key      : 事前発行したAPIキー





# # # # # # # # # # # # # # # # # # # # # # # #
# 認証部分を抽象化
# # # # # # # # # # # # # # # # # # # # # # # #
# 基底クラス
class IAuth {
    [string]RunAuth(){
        # default実装
        return "sample" 
    }
}
# 実装クラス
class AuthID : IAuth {
    [string]RunAuth(){
        # default実装
        return "sample2" 
    }
    AuthID($id,$pass){

    }


}
class AuthStaic : IAuth {
    [string]$key
    [string]RunAuth(){
        # default実装
        return $this.key

    }

    AuthStaic($key){
        $this.key =$key
    }

}
# # # # # # # # # # # # # # # # # # # # # # # #

# ZabbixWebAPI
class ZabbixAPI {
    # メンバー変数
    [string]$authcode
    [string]$url 
    # 認証部分は、別クラスにする。
    [IAuth]$auth
    [void]GetAuthCode(){
        $this.authcode = $this.auth.RunAuth()
    }
    [void]SetURL($url){
        $this.url = $url
    }

    # API実装
    [string]AddHost([string]$hostname,[string]$dispname,[string]$ip){
        $ApiHeaders = @{
            "content-type"  = "application/json"
        }
        $apiURL = $this.url
        $requestbody =@{
            "auth" = $this.authcode
            "id" = 2 #連番などでよい。応答との紐づけ用。
            "jsonrpc" = "2.0"
            "method"  = "host.create"
            "params" = @{
                "host" = $hostname
                "name" = $dispname
                "interfaces" = @{
                    "type" = 2 # 1:ZabbixAgent,2:SNMP,3:IPMI,4:JMX
                    "main" = 1
                    "useip" = 1
                    "ip" = $ip
                    "dns" = ""
                    "port" = "161"
                    "details" = @{
                        "version" = 2
                        "bulk" = 1
                        "community" = "public"
                    }
                }
                "groups" = @{"groupid" = 29} # 事前に確認する
                "templates" =@(   # 事前に確認する
                    @{"templateid" = "10186"}
                    ,@{"templateid" = "11061"}            
                )
            }
        }  | ConvertTo-Json -Depth 10
        
        try {
            $res = Invoke-RestMethod -Uri $apiURL -Method POST -Headers $ApiHeaders -Body $requestbody | ConvertTo-Json -Depth 10
            return $res
        }
        catch {
            throw $_
        }

    }

    [string]GetHostID(){
        $ApiHeaders = @{
            "content-type"  = "application/json"
        }
        $apiURL = $this.url
        $requestbody =@{
            "auth" = $this.authcode
            "id" = 2 #連番などでよい。応答との紐づけ用。
            "jsonrpc" = "2.0"
            "method"  = "host.get"
            "params" = @{
                "selectInventory" = @("software")
            }
            
        }  | ConvertTo-Json -Depth 10
        
        try {
            $res = Invoke-RestMethod -Uri $apiURL -Method POST -Headers $ApiHeaders -Body $requestbody | ConvertTo-Json -Depth 10
            return $res
        }
        catch {
            throw $_
        }
    }


    # インストラクタ
    ZabbixAPI([IAuth]$a){
        $this.auth =$a
    }



}
# # # # # # # # # # # # # # # # # # # # # # # #

function GetNodeInfo{
    param($path="")
    if(-not (test-path $path)){
        return @(0..10)
    }
    # CSVのフォーマット
    # HostName,DispName,IpAddress
    return @(import-csv -Path $path)


}


# # # # # # # MAIN # # # # # # # # # # # # # # #
function main{
    param(
        $authmode = "id"
        ,$id = ""
        ,$pass = ""
        ,$key = ""
        ,$url = ""
        ,$csvpath = ""
    )
    #引数チェック
    if($url -eq ""){
        write-host "API用のURLを指定して" -ForegroundColor Magenta
        write-host "  例 http://＜ip＞/zabbix/api_jsonrpc.php" -ForegroundColor Magenta
        exit -1
    }

    if(($authmode -eq "id") -and ($id -ne "") -and ($pass -ne "")){
        $z = [ZabbixAPI]::new([AuthID]::new($id,$pass))
    }elseif(($authmode -eq "static") -and ($key -ne "")){
        $z = [ZabbixAPI]::new([AuthStaic]::new($key))
    }else{
        write-host "optionが足りない" -ForegroundColor Magenta
        exit -1
    }

    #　操作
    $z.SetURL($url)
    $z.GetAuthCode()
    foreach($a in GetNodeInfo -path $csvpath){
        $z.AddHost($a.HostName,$a.DispName,$a.IpAddress)
    }
  

 
}


main -authmode "static" `
    -key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" `
    -url "http://192.168.0.1/zabbix/api_jsonrpc.php" `
    -csvpath "C:\Users\stsuji\Desktop\aaaa.csv"
