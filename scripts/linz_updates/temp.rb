LINZ_URL="https://data.linz.govt.nz/services;"
#need to check these for validity

linz_key = ENV['nzogps_linz_api_key']
curl_cmd = ENV['nzogps_curl']

#curl_cmd = "echo #{curl_cmd}"

from_date = "2016-07-30T02:06:14.066745"
to_date = "2016-08-13T02:06:09.394426"

nztime = Time.new
to_date = nztime.utc.strftime("%FT%T")

url1 = "#{LINZ_URL}key=#{linz_key}/wfs/layer-"
url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames=layer-"
url3 = "-changeset^&viewparams=from:#{from_date}Z;to:#{to_date}Z^&outputFormat=csv"
#need to add checks for valid return
layer = 779
system("#{curl_cmd} -o layer-#{layer}-cs1.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
layer = 818
system("#{curl_cmd} -o layer-#{layer}-cs1.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
layer = 793
system("#{curl_cmd} -o layer-#{layer}-cs1.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
