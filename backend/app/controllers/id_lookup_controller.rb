class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/repositories/:repo_id/find_by_id/resources')
    .description("Find Resources by their identifiers")
    .example("python") do
      <<~PYTHON
        from asnake.client import ASnakeClient  # import the ArchivesSnake client
        import urllib.parse  # import the urllib.parse package for parsing the URL passed to the API
        
        client = ASnakeClient(baseurl="http://localhost:8089", username="admin", password="admin")
        # Replace "http://localhost:8089" with your ArchivesSpace API URL and "admin" for your username and password
        
        client.authorize()  # authorizes the client
        
        # Finding resources with one identifier field
        resource_id = urllib.parse.quote("my_resource_id")  # replace "my_resource_id" with the ID you're searching for
        find_res_id = client.get(f'repositories/:repo_id:/find_by_id/resources?identifier[]=["{identifier}"];resolve[]=resources')
        # Replace :repo_id: with the repository ID the resource is in and only add ";resolve[]=resources" if you want
        # the JSON for the returned record - otherwise, it will return the record URI only

        print(find_res_id.json())
        # Output (dict): {'resources': [{'ref': '/repositories/2/resources/407', '_resolved':  {'lock_version': 0,...}
    
        # Finding resources with multiple identifier fields
        id_0 = urllib.parse.quote("test")  # replace "test" with the first identifier value
        id_1 = urllib.parse.quote("1234")  # replace "1234" with the second identifier value
        id_2 = urllib.parse.quote("abcd")  # replace "abcd" with the third identifier value
        id_3 = urllib.parse.quote("5678")  # replace "5678" with the fourth identifier value
        find_mult_res_id = client.get(f'repositories/:repo_id:/find_by_id/resources?identifier[]=["{id_0}", "{id_1}", "{id_2}", "{id_3}"];resolve[]=resources')
        # Replace :repo_id: with the repository ID the resource is in and only add ";resolve[]=resources" if you want
        # the JSON for the returned record - otherwise, it will return the record URI only

        print(find_mult_res_id.json())
        # Output (dict): {'resources': [{'ref': '/repositories/2/resources/407', '_resolved':  {'lock_version': 0,...}
      PYTHON
    end
    .params(["repo_id", :repo_id],
            ["identifier", [String], "A 4-part identifier expressed as a JSON array (of up to 4 strings) comprised of the id_0 to id_3 fields (though empty fields will be handled if not provided)", :optional => true],
            ["ark", [String], "An ARK attached to a resource record (param may be repeated)", :optional => true],
            ["resolve", :resolve, "The type of record you are resolving, returns the full JSON for linked record. Example: 'resolve[]': 'resources'", :optional => true])
    .permissions([:view_repository])
    .returns([200, "JSON array of refs"]) \
  do
    refs = IDLookup.new.find_by_ids(Resource, params)
    json_response(resolve_references({'resources' => refs}, params[:resolve]))
  end

  Endpoint.get('/repositories/:repo_id/find_by_id/archival_objects')
    .description("Find Archival Objects by ref_id or component_id")
    .example("shell") do
      <<~SHELL
        curl -s -F password="admin" "http://localhost:8089/users/admin/login"
        # Replace "admin" with your password and "http://localhost:8089/users/admin/login" with your ASpace API URL
        # followed by "/users/{your_username}/login"
    
        set SESSION="session_id"
        # If using Git Bash, replace set with export
    
        curl -H "X-ArchivesSpace-Session: $SESSION" //
        "http://localhost:8089/repositories/:repo_id:/find_by_id/archival_objects?component_id[]=hello_im_a_component_id;resolve[]=archival_objects"
        # Replace "http://localhost:8089" with your ASpace API URL, :repo_id: with the repository ID, 
        # "hello_im_a_component_id" with the component ID you are searching for, and only add 
        # "resolve[]=archival_objects" if you want the JSON for the returned record - otherwise, it will return the 
        # record URI only

        curl -H "X-ArchivesSpace-Session: $SESSION" //
        "http://localhost:8089/repositories/:repo_id:/find_by_id/archival_objects?ref_id[]=hello_im_a_ref_id;resolve[]=archival_objects"
        # Replace "http://localhost:8089" with your ASpace API URL, :repo_id: with the repository ID, 
        # "hello_im_a_ref_id" with the ref ID you are searching for, and only add 
        # "resolve[]=archival_objects" if you want the JSON for the returned record - otherwise, it will return the 
        # record URI only
      SHELL
    end
    .example("python") do
      <<~PYTHON
        from asnake.client import ASnakeClient  # import the ArchivesSnake client
        
        client = ASnakeClient(baseurl="http://localhost:8089", username="admin", password="admin")
        # Replace "http://localhost:8089" with your ArchivesSpace API URL and "admin" for your username and password
        
        client.authorize()  # authorizes the client
        
        find_ao_compid = client.get("repositories/:repo_id:/find_by_id/archival_objects", 
                                    params={"component_id[]": "hello_im_a_component_id",
                                    "resolve[]": "archival_objects"})
        # Replace :repo_id: with the repository ID, "hello_im_a_component_id" with the component ID you are searching for, and
        # only add "resolve[]": "archival_objects" if you want the JSON for the returned record - otherwise, it will 
        # return the record URI only

        print(find_ao_compid.json())
        # Output (dict): {'archival_objects': [{'ref': '/repositories/2/archival_objects/708425', '_resolved':...}]}

        find_ao_refid = client.get("repositories/:repo_id:/find_by_id/archival_objects", 
                                   params={"ref_id[]": "hello_im_a_ref_id"
                                   "resolve[]": "archival_objects"})
        # Replace :repo_id: with the repository ID, "hello_im_a_ref_id" with the ref ID you are searching for, and only add 
        # "resolve[]": "archival_objects" if you want the JSON for the returned record - otherwise, it will return the 
        # record URI only
        
        print(find_ao_refid.json())
        # Output (dict): {'archival_objects': [{'ref': '/repositories/2/archival_objects/708425', '_resolved':...}]}
      PYTHON
    end
    .params(["repo_id", :repo_id],
            ["ref_id", [String], "An archival object's Ref ID (param may be repeated)", :optional => true],
            ["component_id", [String], "An archival object's component ID (param may be repeated)", :optional => true],
            ["ark", [String], "An ARK attached to an archival object record (param may be repeated)", :optional => true],
            ["resolve", :resolve, "The type of record you are resolving, returns the full JSON for linked record. Example: 'resolve[]': 'archival_object'", :optional => true])
    .permissions([:view_repository])
    .returns([200, "JSON array of refs"]) \
  do
    refs = IDLookup.new.find_by_ids(ArchivalObject, params)
    json_response(resolve_references({'archival_objects' => refs}, params[:resolve]))
  end

  Endpoint.get('/repositories/:repo_id/find_by_id/digital_object_components')
    .description("Find Digital Object Components by component_id")
    .example("shell") do
      <<~SHELL
        curl -s -F password="admin" "http://localhost:8089/users/admin/login"
        # Replace "admin" with your password and "http://localhost:8089/users/admin/login" with your ASpace API URL
        # followed by "/users/{your_username}/login"
    
        set SESSION="session_id"
        # If using Git Bash, replace set with export
    
        curl -H "X-ArchivesSpace-Session: $SESSION" //
        "http://localhost:8089/repositories/:repo_id:/find_by_id/digital_object_components?component_id[]=im_a_do_component_id;resolve[]=digital_object_components"
        # Replace "http://localhost:8089" with your ASpace API URL, :repo_id: with the repository ID, 
        # "im_a_do_component_id" with the component ID you are searching for, and only add 
        # "resolve[]=digital_object_components" if you want the JSON for the returned record - otherwise, it will return
        # the record URI only
      SHELL
    end
    .example("python") do
      <<~PYTHON
        from asnake.client import ASnakeClient  # import the ArchivesSnake client
        
        client = ASnakeClient(baseurl="http://localhost:8089", username="admin", password="admin")
        # Replace "http://localhost:8089" with your ArchivesSpace API URL and "admin" for your username and password
        
        client.authorize()  # authorizes the client
        
        find_do_comp = client.get("repositories/:repo_id:/find_by_id/digital_object_components", 
                                  params={"component_id[]": "im_a_do_component_id"
                                  "resolve[]": "digital_object_components"})
        # Replace :repo_id: with the repository ID, "im_a_do_component_id" with the component ID you are searching for, and
        # only add "resolve[]": "digital_object_components" if you want the JSON for the returned record - otherwise, it
        # will return the record URI only
  
        print(find_do_comp.json())
        # Output (dict): {'digital_object_components': [{'ref': '/repositories/2/digital_object_components/1', '_resolved':...}]}
      PYTHON
    end
    .params(["repo_id", :repo_id],
            ["component_id", [String], "A digital object component's component ID (param may be repeated)", :optional => true],
            ["resolve", :resolve, "The type of record you are resolving, returns the full JSON for linked record. Example: 'resolve[]': 'digital_object_components'", :optional => true])
    .permissions([:view_repository])
    .returns([200, "JSON array of refs"]) \
  do
    refs = IDLookup.new.find_by_ids(DigitalObjectComponent, params)
    json_response(resolve_references({'digital_object_components' => refs}, params[:resolve]))
  end

  Endpoint.get('/repositories/:repo_id/find_by_id/digital_objects')
    .description("Find Digital Objects by digital_object_id")
    .example("shell") do
      <<~SHELL
        curl -s -F password="admin" "http://localhost:8089/users/admin/login"
        # Replace "admin" with your password and "http://localhost:8089/users/admin/login" with your ASpace API URL
        # followed by "/users/{your_username}/login"
    
        set SESSION="session_id"
        # If using Git Bash, replace set with export
    
        curl -H "X-ArchivesSpace-Session: $SESSION" //
        "http://localhost:8089/repositories/:repo_id:/find_by_id/digital_objects?digital_object_id[]=hello_im_a_digobj_id;resolve[]=digital_objects"
        # Replace "http://localhost:8089" with your ASpace API URL, :repo_id: with the repository ID, 
        # "hello_im_a_digobj_id" with the digital object ID you are searching for, and only add 
        # "resolve[]=digital_objects" if you want the JSON for the returned record - otherwise, it will return the 
        # record URI only
      SHELL
    end
    .example("python") do
      <<~PYTHON
        from asnake.client import ASnakeClient  # import the ArchivesSnake client
        
        client = ASnakeClient(baseurl="http://localhost:8089", username="admin", password="admin")
        # Replace "http://localhost:8089" with your ArchivesSpace API URL and "admin" for your username and password
        
        client.authorize()  # authorizes the client
        
        find_do = client.get("repositories/:repo_id:/find_by_id/digital_objects", 
                             params={"digital_object_id[]": "hello_im_a_digobj_id", 
                                     "resolve[]": "digital_objects"})
        # Replace :repo_id: with the repository ID, "im_a_digobj_id" with the digital object ID you are searching for, and
        # only add "resolve[]=digital_objects" if you want the JSON for the returned record - otherwise, it will return 
        # the record URI only
  
        print(find_do.json())
        # Output (dict): {'digital_objects': [{'ref': '/repositories/2/digital_objects/1', '_resolved':...}]}
      PYTHON
    end
    .params(["repo_id", :repo_id],
            ["digital_object_id", [String], "A digital object's digital object ID (param may be repeated)", :optional => true],
            ["resolve", :resolve, "The type of record you are resolving, returns the full JSON for linked record. Example: 'resolve[]': 'digital_objects'", :optional => true])
    .permissions([:view_repository])
    .returns([200, "JSON array of refs"]) \
  do
    refs = IDLookup.new.find_by_ids(DigitalObject, params)
    json_response(resolve_references({'digital_objects' => refs}, params[:resolve]))
  end

end
