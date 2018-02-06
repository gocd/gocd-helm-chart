#!/usr/bin/env ruby

if File.basename($0) != "rake"
  require 'shellwords'
  puts "rake -f #{Shellwords.escape($0)} #{Shellwords.shelljoin(ARGV)}"
  exec "rake -f #{Shellwords.escape($0)} #{Shellwords.shelljoin(ARGV)}"
end

$stdout.sync = true
$stderr.sync = true

def env(key)
  value = ENV[key].to_s.strip
  fail "Please specify #{key}" if value == ''
  value
end

cluster_name = env('CLUSTER_NAME')
project_name = env('PROJECT_NAME')
region = ENV['REGION'] || 'us-east1-b' # should be set up at the pipeline level
release_name = 'gocd-helm-release'
machine_type = ENV['MACHINE_TYPE'] || 'n1-standard-2'

task :create_cluster do
  num_of_nodes = ENV['NUMBER_OF_NODES'] || 1
  disk_size = ENV['NODE_DISK_SIZE'] || 50

  sh("gcloud config set project #{project_name}")
  sh("gcloud container clusters create #{cluster_name} --disk-size=#{disk_size} --num-nodes=#{num_of_nodes} --zone #{region} --machine-type=#{machine_type} --cluster-version=1.8.7-gke.0 || true")
  sh("gcloud container clusters get-credentials #{cluster_name} --zone #{region}")
  sh("helm init --upgrade ")
end

task :run_helm_checks do
  repo_url = env('REPO_URL')
  type_of_helm_repo = ENV['HELM_REPO'] || 'stable'

  rm_rf 'charts'
  sh("git clone #{repo_url} charts")
  sh("helm lint charts/#{type_of_helm_repo}/gocd")
  sh("helm install charts/#{type_of_helm_repo}/gocd --name #{release_name}")
  sh("helm test #{release_name}")
end

task :teardown_cluster do
  sh("helm delete --purge #{release_name}")
  sh("gcloud container clusters delete #{cluster_name} --quiet --zone #{region}")
end