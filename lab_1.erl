-module(lab_1).
-compile(export_all).

firm() ->

  receive
     done ->
       io:format("Firm: done~n");
     orderRequest ->
       pingLoop(pang,'pidClient'),
       io:format("Firm: new client! new invoice"),
       resolvePid(pidClient) ! invoice,
       firm();
     paymentReceived ->
       pingLoop(pang, 'pidClient'),
       io:format("Firm: payment recieved!"),
       resolvePid(pidClient) ! cargoRequest,
       firm();
     cargoToFirm ->
       pingLoop(pang, 'pidProvider'),
       io:format("Firm: ordering truck!"),
       resolvePid(pidProvider) ! truckRequest,
       firm();
     truckFound ->
       pingLoop(pang, 'pidProvider'),
       io:format("Firm: truck found, sending!"),
       resolvePid(pidProvider) ! cargoToProvider,
       firm();
     orderFinished ->
       io:format("Firm: well done!"),
       firm()
end.
 
bank() ->

  receive
     done ->
       io:format("Bank: done~n");
     payment ->
       pingLoop(pang,'pidFirm'),
       io:format("Bank: payment received, sending message to firm"),
     resolvePid(pidFirm) ! paymentReceived
   end,
bank().
 
receiver() ->

  receive
     done ->
       io:format("Receiver: done");
     cargoDone->
       io:format("Receiver: it's here!"),
       pingLoop(pang, 'pidClient'),
       io:format("Receiver: notify client!"),
       resolvePid(pidClient) ! jobDone,
       pingLoop(pang, 'pidFirm'),
       io:format("Receiver: notify firm!"),
       resolvePid(pidFirm) ! orderFinished,
       receiver()
  end.
 
provider() ->

  receive
     done ->
       io:format("Provider: done");
     truckRequest ->
       pingLoop(pang, 'pidFirm'),
       io:format("Provider: looking for a truck... done!"),
       resolvePid(pidFirm) ! truckFound,
       provider();
     cargoToProvider ->
       pingLoop(pang, 'pidReceiver'),
       io:format("Provider: cargo received, truck sent"),
       resolvePid(pidReceiver)!cargoDone,
       provider()
  end.
client(0, _) ->
  io:format("Client: finally done!"),
  pingLoop(pang, 'pidFirm'),
  resolvePid(pidFirm) ! done,
  pingLoop(pang, 'pidBank'),
  resolvePid(pidBank) ! done,
  pingLoop(pang, 'pidProvider'),
  resolvePid(pidProvider)!done,
  pingLoop(pang, 'pidReceiver'),
  resolvePid(pidReceiver) ! done;
client(Index, 0) ->

     pingLoop(pang, 'pidFirm'),
     io:format("Client: new client!"),
     resolvePid(pidFirm) ! orderRequest,
     client(Index, 1);
client(Index,1) ->

  receive
     invoice ->
       pingLoop(pang,'pidBank'),
       io:format("Client: invoice received, ready to pay"),
       resolvePid(pidBank) ! payment,
       client(Index, 1);
     cargoRequest ->
       pingLoop(pang, 'pidFirm'),
       io:format("Client: sending cargo to firm"),
       resolvePid(pidFirm) ! cargoToFirm,
       client(Index, 1);
     jobDone ->
       io:format("Client: order complete"),
       client(Index - 1, 0)
  end.

  
runFirmNode() ->
  global:register_name(pidFirm, spawn(lab_1, firm,[])).
 
runBankNode() ->
  global:register_name(pidBank, spawn(lab_1, bank,[])).
 
runClientNode(N) ->
  global:register_name(pidClient, spawn(lab_1,client, [N, 0])).
 
runReceiverNode() ->
  global:register_name(pidReceiver, spawn(lab_1, receiver,[])).
 
runProviderNode() ->
  global:register_name(pidProvider, spawn(lab_1, provider, [])).
%% ==============================================
%% Internal functions
%% =================================================
resolvePid(Atom) ->

  %io:format("Pid ~n",[string:concat(erlang:atom_to_list(Atom), "@127.0.0.1")]),
  global:whereis_name(Atom).
 
buildNodeAddress(Atom) ->

    list_to_atom(string:concat(erlang:atom_to_list(Atom), "@192.168.1.6")).
 
pingLoop(pong, NodeName) ->
  %io:format("node ~s registered  ~n",[NodeName]), 
  checkNodeByName(resolvePid(NodeName), NodeName),
  pingOK;
  
pingLoop(pang, NodeName) ->
  timer:sleep(3333),
  pingLoop(net_adm:ping(buildNodeAddress(NodeName)), NodeName).
 
checkNodeByName(undefined, NodeName) ->
  pingLoop(pang, NodeName);
checkNodeByName(_, _) ->
  %io:format("node ~s registered  ~n",[NodeName]),
  checkOK.
