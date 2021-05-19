-module(lab_1).
-compile(export_all).

manager() ->

  receive
     done ->
       io:format("Manager: done\n");
     orderRequest ->
       pingLoop(pang,'pidBox'),
       io:format("Manager: new client! send order to the box_office\n"),
       resolvePid(pidBox) ! get_order,
       manager();
    give_dish ->
       pingLoop(pang,'pidClient'),
       io:format("Manager: i get a dish, give to the client and wait for payment\n"),
       resolvePid(pidClient) ! give_dish,
       manager();
     paymentReceived ->
       pingLoop(pang, 'pidBox'),
       io:format("Manager: payment recieved!\n"),
       resolvePid(pidBox) ! payment,
       manager();
    paymentNotify ->
       pingLoop(pang, 'pidClient'),
       io:format("Manager: payment well done!\n"),
       resolvePid(pidClient) ! notify,
       manager();
     orderFinished ->
       io:format("Manager: well done!\n"),
       manager()
end.
 
box_office() ->

  receive
     done ->
       io:format("box_office: done\n");
    get_order ->
        io:format("box_office: i get an order and send to the cook\n"),
        pingLoop(pang, 'pidCook'),
        resolvePid(pidCook) ! get_order;
     payment ->
       pingLoop(pang,'pidManager'),
       io:format("box_office: payment received, sending message to manager\n"),
     resolvePid(pidManager) ! paymentNotify
   end,
box_office().
 
 
cook() ->

  receive
     done ->
       io:format("cook: done\n");
    get_order ->
        io:format("cook: get an order \n"),
        pingLoop(pang, 'pidWarehouse'),
        resolvePid(pidWarehouse) ! request_ingredients;
    give_ingredients ->
        io:format("cook: send dish to the manager\n"),
        pingLoop(pang, 'pidManager'),
        resolvePid(pidManager) ! give_dish
   end,
cook().

warehouse() ->

  receive
     done ->
       io:format("warehouse: done\n");
    request_ingredients ->
        io:format("warehouse: get a request\n"),
        pingLoop(pang, 'pidDelivery'),
        resolvePid(pidDelivery) ! get_ingredients;
    jobDone -> 
        io:format("warehouse: i have an ingredients\n"),
        pingLoop(pang, 'pidCook'),
        resolvePid(pidCook) ! give_ingredients
   end,
warehouse().

delivery() ->

  receive
     done ->
       io:format("Delivery: done\n");
     get_ingredients->
       io:format("Delivery: i get a order!\n"),
       pingLoop(pang, 'pidWarehouse'),
       io:format("Delivery: i send ingredients\n"),
       resolvePid(pidWarehouse) ! jobDone,
       delivery()
  end.
 

client(0, _) ->
  io:format("Client: finally done!\n"),
  pingLoop(pang, 'pidManager'),
  resolvePid(pidManager) ! done,
  
  pingLoop(pang, 'pidBox'),
  resolvePid(pidBox) ! done,
  
    pingLoop(pang, 'pidCook'),
  resolvePid(pidCook) ! done,
  
  pingLoop(pang, 'pidWarehouse'),
  resolvePid(pidWarehouse) ! done,
  
  pingLoop(pang, 'pidDelivery'),
  resolvePid(pidDelivery)!done;
  
client(Index, 0) ->

     pingLoop(pang, 'pidManager'),
     io:format("Client: new client!\n"),
     resolvePid(pidManager) ! orderRequest,
     client(Index, 1);
     
client(Index,1) ->
  receive
    give_dish ->
       pingLoop(pang,'pidManager'),
       io:format("Client: i get a dish\n"),
       resolvePid(pidManager) ! paymentReceived,
       client(Index, 1);

    notify ->
       io:format("Client: order complete\n\n"),
        client(Index - 1, 0)
  end.
  
runManagerNode() ->
  global:register_name(pidManager, spawn(lab_1, manager,[])).
 
runBox_officeNode() ->
  global:register_name(pidBox, spawn(lab_1, box_office,[])).
 
runCookNode() ->
  global:register_name(pidCook, spawn(lab_1, cook,[])).
 
runWarehouseNode() ->
  global:register_name(pidWarehouse, spawn(lab_1, warehouse,[])).
  
runDeliveryNode() ->
  global:register_name(pidDelivery, spawn(lab_1, delivery,[])). 

runClientNode(N) ->
  global:register_name(pidClient, spawn(lab_1,client, [N, 0])).
 
%% ==============================================
%% Internal functions
%% =================================================
resolvePid(Atom) ->
  global:whereis_name(Atom).
 
buildNodeAddress(Atom) ->

    list_to_atom(string:concat(erlang:atom_to_list(Atom), "@192.168.1.6")).
 
pingLoop(pong, NodeName) ->
  checkNodeByName(resolvePid(NodeName), NodeName),
  pingOK;
  
pingLoop(pang, NodeName) ->
  timer:sleep(3333),
  pingLoop(net_adm:ping(buildNodeAddress(NodeName)), NodeName).
 
checkNodeByName(undefined, NodeName) ->
  pingLoop(pang, NodeName);
  
checkNodeByName(_, _) ->
  checkOK.
