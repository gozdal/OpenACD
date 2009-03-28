/* dependancies */
dojo.require("dijit.Dialog");
dojo.require("dijit.layout.LayoutContainer");
dojo.require("dijit.layout.ContentPane");
dojo.require("dijit.layout.TabContainer");
dojo.require("dijit.form.Button");
dojo.require("dijit.form.Form");
dojo.require("dijit.form.TextBox");
dojo.require("dijit.form.ValidationTextBox");
dojo.require("dijit._tree.dndSource");
dojo.require("dijit.Tree");
dojo.require("dojo.data.ItemFileWriteStore");
dojo.require("dojo.data.ItemFileReadStore");
dojo.require("dojox.encoding.digests.MD5");


currenttab = undefined;

dojo.xhrGet({
	url:"/checkcookie",
	handleAs:"json",
	error:function(response, ioargs){
		console.log("checkcookie failed!");
		console.log(response);
	},
	load:function(response, ioargs){
		if(response.success){
			dojo.byId("main").style.display="block";
			dojo.byId("main").style.visibility = "visible";
			agent = new Agent(response.login);
			buildReleaseMenu(agent);
			buildOutboundMenu(agent);
			dojo.byId("agentname").innerHTML = response.login;
			agent.state = response.state;
			dojo.publish("agent/state", [{"state":response.state, "statedata":response.statedata}]);
		}
		else{
			dijit.byId("loginpane").show();
		}
	}
});



function switchtab(tab) {
	if (currenttab != tab)
		console.log("switched tab to "+tab);
	currenttab = tab;
}

function inspect(obj){
	console.log(obj);
	for(var i in obj){
		console.log("  " + i + ": " + obj[i])
	}
}

function selectskill(item) {
	if (item.type == "skill") {
		dijit.byId("editSkillGroupPane").domNode.style.display="none";
		dijit.byId("editSkillPane").domNode.style.display="block";
		dijit.byId("skillAtom").setValue(item.atom);
		dijit.byId("skillName").setValue(item.name);
		dijit.byId("skillDesc").setValue(item.description);
		dijit.byId("skillAtom").setDisabled(true);
		dijit.byId("skillName").setDisabled(item.protected == "true");
		dijit.byId("skillDesc").setDisabled(item.protected == "true");
		dijit.byId("bsetskill").setDisabled(item.protected == "true");
		dijit.byId("skillPane").refresh();
	} else if (item.type == "group") {
		dijit.byId("editSkillGroupPane").domNode.style.display="block";
		dijit.byId("editSkillPane").domNode.style.display="none";
		dijit.byId("skillPane").refresh();
	}
}

function selectqueue(item) {
	if (item.type == "queue") {
		dijit.byId("editQueueGroupPane").domNode.style.display="none";
		dijit.byId("editQueueGeneralPane").domNode.style.display="none";
		dijit.byId("editQueuePane").domNode.style.display="block";
		dijit.byId("queuePane").refresh();
	} else if (item.type == "group") {
		dijit.byId("editQueueGroupPane").domNode.style.display="block";
		dijit.byId("editQueueGeneralPane").domNode.style.display="none";
		dijit.byId("editQueuePane").domNode.style.display="none";
		dijit.byId("queuePane").refresh();
	}
}

function skillDragCheckAcceptance(source, nodes) {
	if (nodes.length != 1)
		return false;
	var item = dijit.getEnclosingWidget(nodes[0]).item;
	return (item.type == "skill");
};

function skillDragCheckItemAcceptance(target, source) {
	var item = dijit.getEnclosingWidget(target).item;
	return (item.type == "group");
};

dojo.addOnLoad(function() {
	var tabbar = dijit.byId("mainTabContainer");
	currenttab = dijit.byId("agentsTab");
	dojo.connect(tabbar,'selectChild','switchtab');
	dojo.connect(dijit.byId('itemTree'), 'onClick', 'selectskill');
	dojo.connect(dijit.byId('queueTree'), 'onClick', 'selectqueue');
	dojo.connect(dijit.byId("bsetskill"), 'onClick', function(foo) {
		console.log(foo.target)
	});
	dojo.connect(dijit.byId("generalQueueSettings"), 'onClick', function(foo) {
		dijit.byId("editQueueGroupPane").domNode.style.display="none";
		dijit.byId("editQueueGeneralPane").domNode.style.display="block";
		dijit.byId("editQueuePane").domNode.style.display="none";
		dijit.byId("queuePane").refresh();
	});


	dojo.connect(dijit.byId("removeSkill"), 'onClick', function(foo) {
		var item = dijit.byId("itemTree").lastFocused;
		alert("Remove "+ item.label + " skill");
	});
	dojo.connect(dijit.byId("itemTree").dndController, 'onDndDrop', function(source, nodes, copy) {
		var item = dijit.getEnclosingWidget(nodes[0]).item;
		var newparent = dijit.byId("itemTree")._itemNodeMap[dijit.byId("itemTree").model.getIdentity(item)].getParent().item;
		console.log("moved "+item.name+" into group "+newparent.name);
		dojo.xhrPost( {
			// The following URL must match that used to test the server.
			url: "http://freecpx.dev:9999/update_skill",
			handleAs: "json",
			content: {atom: item.atom, group: newparent.name},
			load: function(responseObject, ioArgs) {
				// Now you can just use the object
				console.dir(responseObject);  // Dump it to the console
				console.dir(responseObject.cobblers[0].filling);  // Prints "peach"
				return responseObject;
				}
			// More properties for xhrGet...
		});
	});
});

function setSkill(e){
	console.log("what is e " + e)
	// prevent the form from actually submitting
	e.preventDefault(); 
	// submit the form in the background	
	dojo.xhrPost({
		url: "setskill",
		form: "editSkillForm",
		handleAs: "json",
		content:{
			"skillatom":dijit.byId("skillAtom").getValue(),
			"action" : "set"
		},
		handle: function(data,args){
			if(typeof data == "error"){
				console.warn("error!",args);
			}else{
				// show our response 
				console.log("success!"),
				inspect(data);
			}
		}
	});
};

dojo.addOnLoad(function(){
	var loginform = dijit.byId("loginform")
	dojo.connect(loginform, "onSubmit", function(e){
		e.preventDefault();
		if (loginform.isValid()){
			dojo.xhrGet({
				url:"/getsalt",
				handleAs:"json",
				error:function(response, ioargs){
					dojo.byId("loginerrp").style.display = "block";
					dojo.byId("loginerrspan").innerHTML = response.responseText;
				},
				load:function(response, ioargs){
					salt = response.salt;
					attrs = loginform.attr("value");
					md5pass = dojox.encoding.digests.MD5(attrs.password, dojox.encoding.digests.outputTypes.Hex);
					salted = dojox.encoding.digests.MD5(salt + md5pass, dojox.encoding.digests.outputTypes.Hex);
					values = attrs;
					values.password = salted;
					dojo.xhrPost({
						url:"/login",
						handleAs:"json",
						content:values,
						load:function(response2, ioargs2){
							if(response2.success){
								EventLog.log("Logged in");
								dijit.byId("loginpane").hide();
								dojo.byId("mainTabContainer").style.display="block";
								dojo.byId("mainTabContainer").style.visibility = "visible";
								console.log(response2);
							}
							else{
								dojo.byId("loginerrp").style.display = "block";
								dojo.byId("loginerrspan").innerHTML = response2.message;
							}
						}
					});
				}
			});
		}
	});









	var theForm = dijit.byId("editSkillPane");
	// another dojo.connect syntax: call a function directly	
	dojo.connect(theForm,"onsubmit",setSkill);
});


