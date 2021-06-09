# This file is to be executed inside a remote machine
CONFIG="/tmp/config.yml"
WEAVE_URL="$(cat $CONFIG | yq eval '.Nomad.Components.Weave.Repo' -)"
WEAVE_PASS="$(cat $CONFIG | yq eval '.Nomad.Components.Weave.Password' -)"

sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod a+x /usr/local/bin/weave

export CHECKPOINT_DISABLE=1
#export WEAVE_PASSWORD=$WEAVE_PASS

# assemble nomad followers
cluster=""
num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"
for ((i=0;i<=$num_nomad_follower-2;i++)); do
    addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.InternalAddr" -)"
    if [ "$(ifconfig | grep -q $addr; echo $?)" == 1 ]; then
        cluster="${cluster} ${addr} "
    fi
done

addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$((num_nomad_follower-1)).InternalAddr" -)"
if [ "$(ifconfig | grep -q $addr; echo $?)" == 1 ]; then
    cluster="${cluster}${addr}"
fi

echo $cluster
sleep 5
weave stop
weave launch --no-dns $cluster
eval $(weave env)

sleep 10
weave status
