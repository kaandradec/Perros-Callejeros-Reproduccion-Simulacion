model code_simulation

global {
	

	shape_file road_file <- shape_file("../maps/m2_calles.shp");
	shape_file building_file <- shape_file("../maps/m_const.shp");

//	shape_file road_file <- shape_file("../maps/try road.shp"); //fixed not whole mayondon
//	shape_file building_file <- shape_file("../maps/buildings.shp"); //fixed not whole mayondon

	geometry shape <- envelope(road_file);
	graph road_network;
	
	int numeros_perros_macho <- 17; // Número inicial de perros macho 65.5% machos
	int numeros_perro_hembra <- 9; // Número inicial de perros hembra
	float velocidad_agente <- 4 #km / #h;
	float probabilidad_crianza <- 0.02; //Probabilidad de reproducirse (breed) cuando se cumple la condición 
	//(por ejemplo, macho encuentra hembra adulta). En cada oportunidad de cruce, se evalúa un flip(probabilidad_crianza) para decidir si efectivamente ocurre la reproducción.
	float step <- 1440 #mn; // minutos   (1440 es un dia)
	int numero_fuentes_comida <- 10; //Cantidad de fuentes de comida a crear en el entorno. Cada fuente de comida se ubica en un punto de la red.
	int umbral_hambre <- 300; //Umbral de “hambre” a partir del cual el agente buscará comida. Cuando decide buscar comida.
	// En reflex when_hungry, se evalúa hunger >= when_hungry_get_food para dirigir al agente hacia una fuente de comida.
	int umbral_muerte_hambre <- 700; //Umbral de hambre máximo: si hunger = die_when_hungry, el agente muere de hambre.
	int max_crias_global <- 6; //Número máximo global de crías en una camada.
	// En el código dentro de la acción breed, se usa rnd(1, max_offspring) para decidir cuántas crías nacerán en esa reproducción.
	float probabilidad_muerte_accidental <- 0.00001; //Probabilidad de muerte accidental en cada ciclo/reflex.


	// Carro Remolque
	bool activar_carro <- true; // Activar o no el carro de captura
	
	int total_perros_esterilizados <- 0;
	int total_perros <-  0;
	
	
	int umbral_sobrepoblacion <- 40; // Ajusta según tu criterio
	
	
	
	list<list<string>> registros_reproducciones <- [];
	bool header_written <- false;
	list<string> registro_reproduccion <- [];
	
	
    action write_reproductions_csv {
        string file_path <- "../output/reproducciones.csv";
        string delimiter <- ",";

        // Escribir el encabezado (reemplazar si el archivo ya existe)
        save "cycle" + delimiter + "location_x" + delimiter + "location_y" + delimiter + "num_crias" to: file_path type: "text" rewrite: true;

		loop tmp over: registros_reproducciones { 		
			
			save [name, location, host] to: "save_data.csv" format: "csv";
				
          	string line <- string(tmp at 0) + delimiter + string(tmp at 1) + delimiter + string(tmp at 2) + delimiter + string(tmp at 3);
            save line to: file_path type: "text" rewrite: false; // Append to the file
		}
        
       
        write "Archivo CSV de reproducciones guardado en: " + file_path; // Mensaje de confirmación
    }
    
    
	


	init {
		create calles from: road_file;
		create construcciones from: building_file;
		road_network <- as_edge_graph(calles);

		create fuente_comida number: numero_fuentes_comida{
			calles rd <- one_of(road_network);
			location <- any_location_in(rd);
		}
		
		create perros_macho number: numeros_perros_macho {
			speed <- velocidad_agente;
			calles rd <- one_of(road_network);
			location <- any_location_in(rd);
		}
		
		create perros_hembra number: numeros_perro_hembra{
			speed <- velocidad_agente;
			calles rd <- one_of(road_network);
			location <- any_location_in(rd);

		}
		
		if activar_carro {
			create carro number: 1 {
				// Poner el carro en algún lugar inicial
				calles rd <- one_of(road_network);
				location <- any_location_in(rd);
			}
		}	
	}
}


species fuente_comida{
	rgb color <- rgb (255, 128, 0, 255);
	
	 aspect cuadrado {
        // Dibuja un cuadrado de lado 10 unidades. Ajusta 10 al tamaño que necesites.
        draw square(10) color: rgb (255, 128, 0, 255); // naranja
    }
}


species perros_hembra skills: [moving]{
	int hambre;
	int edad;
	string edad_categoria;
	rgb color <- #red;
	point target <- nil;
	int total_crias <- rnd(70, 120); // número máximo de crias
	int max_crias_individual <- rnd(3, 6);
	int crias_actuales;
	int numero_crias;
	
	bool esterilizado <- false;

	
	//365 = 1 year
	
	reflex incrementar_edad {
		edad <- edad + 1;
		
		if (edad = 1){
			edad_categoria <- "cachorro";
		}
		if (edad = 1095){//3years
			edad_categoria <- "adulto";
		}
		if (edad = 3650){ // 10 anios
			edad_categoria <- "senior";
		}
	}
	
	reflex aumentar_hambre {
        hambre <- hambre + 1;
    }
   
    reflex buscar_comida when: hambre > umbral_hambre {
    	target <- point(one_of(fuente_comida));
    	if location = target{
    		hambre <- 0;
    	}
    }
    
    reflex deambular when: hambre <= umbral_hambre and target = nil {
    	calles rd <- one_of(road_network);
    	target <- any_location_in(rd);
    }
    
    reflex muere_por_hambre when: hambre = umbral_muerte_hambre{
    	write "Perro Hembra: muere por hambre";
    	do die;
    }
    
    reflex muere_por_vejez when: edad = 5110{ // muerte a los 14 anios
    	write "Perro Hembra: muere por vejez" ;
		do die;
	}
	reflex muerte_accidental when: flip(probabilidad_muerte_accidental) { // flip retorna true cuando la prob es 1
		write "Perro Hembra: muere por accidente";
		do die;
	}
    
    // Reflex para movimiento hacia objetivo si existe
    reflex mover when: target != nil {
		do goto target: target on: road_network ; 
			if target = location {
	    	target <- nil ;
		}
	}
	
	aspect sphere {
		draw sphere(5) color:  #red;
	}

	
  	// Atributo para controlar si ya no puede tener más crías
	bool no_puede_criar_mas <- false;

	action reproducirse {
		if edad_categoria = "adulto" and not esterilizado{
			numero_crias <- rnd(1, max_crias_global);
			
			int num_crias_hembra <- rnd(0, numero_crias);
    		int num_crias_macho <- numero_crias - num_crias_hembra;
    		
    		
    		total_perros <- (total_perros + num_crias_hembra + num_crias_macho);
    		
			create species(perros_hembra) number: num_crias_hembra  {
				edad <- 1;
				hambre <- 0;
				edad_categoria <- "cachorro";
				speed <- velocidad_agente;
				location <- myself.location;
			}
			create species(perros_macho) number: num_crias_macho {
        		edad <- 1;
        		hambre <- 0;
        		edad_categoria <- "cachorro";
        		speed <- velocidad_agente;
				location <- myself.location;
			}
			
			// --- CÓDIGO MODIFICADO: AHORA GUARDA EN LA LISTA GLOBAL ---
            list<string> fila_registro <- [
                string(cycle),
                string(location.x),
                string(location.y),
                string(numero_crias)
            ];
            add fila_registro to: registros_reproducciones;
            
            
            
             list<string> registro <- [
                string(cycle),
                string(location.x),
                string(location.y),
                string(numero_crias)
            ];
            registro_reproduccion <- [string(cycle),string(location.x),string(location.y),string(numero_crias)];
            
            
            
            string tspam <- string(seed) + "_" + string(cycle) ;
//            string ruta <- "../output/reproducciones/reproduccion_" + tspam + ".csv";

			string ruta <- "../output/reproducciones/reproduccion.csv";


	            if (not header_written) {
      save "cycle,location_x,location_y,num_crias"
        to: ruta
        format: "text"
        rewrite: true;
      header_written <- true;
    }

            
            
            save [string(cycle), string(location.x), string(location.y), string(numero_crias)]
		      to: ruta
		      format: "csv"
		      header: false
		      rewrite: false;

			
		}
	}
	
	 action sterilize {
        if not esterilizado {
            esterilizado <- true;
            total_perros_esterilizados <- total_perros_esterilizados + 1;
            write "Perro Hembra: Esterilizado";
        }
    }
}

species perros_macho skills: [moving] {
	int hambre <- 0;
	int edad;
	string edad_categoria;
	rgb color <- #blue;
	point target <- nil;
	
	bool esterilizado <- false;
	

	//365 = 1 year
	reflex incrementar_edad {
		edad <- edad + 1;
		if (edad = 1){
			edad_categoria <- "cachorro";
		}
		if (edad = 365){ // 1 anio
			edad_categoria <- "adulto";
		}
		if (edad = 3650){ // 10 anios
			edad_categoria <- "senior";
		}
	}
	
	
	reflex aumentar_hambre {
        hambre <- hambre + 1;
    }
    
   // Reflex para buscar comida cuando está hambriento
    reflex buscar_comida when: hambre > umbral_hambre {
    	target <- point(one_of(fuente_comida));
    	if location = target{
    		hambre <- 0;
    	}
    }
    
    // Reflex para moverse al azar cuando no está hambriento
     reflex deambular when: hambre <= umbral_hambre and target = nil {
    	calles rd <- one_of(road_network);
    	target <- any_location_in(rd);
    }
    
    reflex muere_por_hambre when: hambre = umbral_muerte_hambre{
    	write "Perro Macho: muere por hambre";
    	do die;
    }
    
    reflex muere_por_vejez when: edad = 5110{
    	write "Perro Macho: muere por vejez";
		do die;
	}
	reflex muerte_accidental when: flip(probabilidad_muerte_accidental) {
		write "Perro Macho: muere por accidente";
		do die;
	}
    
	reflex mover when: target != nil {
		do goto target: target on: road_network ; 
			if target = location {
	    	target <- nil ;
		}
	}
	aspect sphere {
		draw sphere(5)color:  #blue;
	}
	
	reflex reproducirse when: edad_categoria = "adulto" and not esterilizado{
		ask perros_hembra at_distance 0 {
			if flip(probabilidad_crianza) and no_puede_criar_mas = false{
				do reproducirse;
				crias_actuales <- crias_actuales + numero_crias;
				if crias_actuales >= total_crias {
					no_puede_criar_mas <- true;
				}
			}
		}
	}
	
	// Action for sterilization - can be called by the carro
    action sterilize {
        if not esterilizado {
            esterilizado <- true;
            total_perros_esterilizados <- total_perros_esterilizados + 1;
            write "Perro Hembra: Esterilizado";
        }
    }
	
	}
	
	
species carro skills: [moving] {
    // Atributos:
    point target <- nil;
    bool is_working_time;
    float arrival_threshold <- 2.0;


    reflex update_working_status {
	//	is_working_time <- true;
//		total_perros <- count (perros_macho, true)  + count (perros_hembra, true);
		
		if total_perros >= umbral_sobrepoblacion {
	        is_working_time <- true;
	    } else {
	        is_working_time <- false;
	    }
    }

  // Reflex of movement: deambulate randomly by the network when working
    reflex mover when: is_working_time and target = nil { // Only move if working and not already going somewhere
    	write "Carro: Deambulando";
        calles tramo <- one_of(road_network);
        target <- any_location_in(tramo); // Set a random target point
        // write "Carro: Setting new random target."; // Debugging
    }

     reflex mover when: is_working_time {
        // Lógica simple: escoger aleatoriamente un tramo y moverse:
        calles tramo <- one_of(road_network);
        do goto target: any_location_in(tramo) on: road_network;
        // Si deseas patrullar, podrías usar otra heurística
    }


    // Reflex de captura: si coincide con un perro adulto no esterilizado y hay jaulas libres
	reflex capturar when: is_working_time {
	    ask perros_hembra at_distance 5 { // Radio reducido
	        if (not esterilizado) {
	            do sterilize; // Call the dog's sterilize action

                write "Carro: Esterilizado un perra en " + location; // Message upon successful sterilization
	        }
	    }
	}


    
    aspect base {
		// Cambiar color si está trabajando o no
		rgb display_color <- #black;
		display_color <- #green; 
		draw rectangle(30, 15) color: #green;
	}
}
	

species calles {
	geometry display_shape <- shape + 2.0;

	aspect base {
		draw shape color: #black depth: 3.0;
	}
}

species construcciones {
	string type;
	rgb color <- #gray;
}




experiment main_experiment type: gui {
	parameter "Número inicial de perros macho" var: numeros_perros_macho min: 0 max: 200;
	parameter "Número inicial de perros hembra" var: numeros_perro_hembra min: 0 max: 200;
	parameter "Probabilidad de reproducción" var: probabilidad_crianza min: 0.0 max: 0.5;
	parameter "Número de fuentes de comida" var: numero_fuentes_comida min: 0 max: 20;
	parameter "Umbral hambre" var: umbral_hambre min: 0 max: 500; // Valores bajos: busca pronto, bajo riesgo de inanición. Valores altos: busca tarde, mayor riesgo de no llegar a tiempo.
	parameter "Umbral muerte por hambre" var: umbral_muerte_hambre min: 0 max: 2000; // Valores bajos: muere con poco hambre, supervivencia corta. Valores altos: aguanta más tiempo sin comer, menor mortalidad por hambre.
	parameter "Velocidad de los perros" var: velocidad_agente min: 0.0 max: 1.0;
	parameter "Probabilidad de muerte accidental" var: probabilidad_muerte_accidental min: 0.000001 max: 0.0005 ;
	
	
//	reflex guardar_en_csv {
//	  if (registro_reproduccion != []) {
//	    bool cabecera <- cycle = 0;
//	    save registro_reproduccion
//	      to: "../output/registro_reproducciones.csv"
//	      format: "csv"
//	      header: cabecera
//	      rewrite: cabecera;
//	    // Limpiar el registro para el próximo ciclo
//	    registro_reproduccion <- [];
//	  }
//	}

  	

	
	output {
		
		
	
		display map_2D type: 2d {
			
				species construcciones transparency: 0.8;
				species calles aspect: base;
				species perros_macho aspect: sphere;
				species perros_hembra aspect: sphere;
				species fuente_comida aspect: cuadrado;
				species carro aspect: base;
				
				}
				display serie_temporal_categorias type: 2d refresh: every(10 #cycles){
					chart "Conteo de agentes" type: series{
						data "cachorro" value: perros_macho count (each.edad_categoria="cachorro")  color: #limegreen;
						data "adulto" value: perros_macho count (each.edad_categoria="adulto") color: #gamaorange;
						data "senior" value: perros_macho count (each.edad_categoria="senior") color: #tomato;
					}
				}
				display serie_temporal_total_perros type: 2d refresh: every(10 #cycles){
					chart "Total perros" type: series{
						data "total perros" value: 
						perros_macho count (each.edad_categoria = "cachorro")+ 
						perros_macho count(each.edad_categoria = "adulto") + 
						perros_macho count(each.edad_categoria = "senior") +
						perros_hembra count(each.edad_categoria = "cachorro")+
						perros_hembra count(each.edad_categoria = "adulto")+
						perros_hembra count(each.edad_categoria = "senior");
						
					}
				}
				display serie_temporal_machos_vs_hembras refresh: every(10#cycles) type:2d{
					chart "Conteo total por generos" type: series {
						data "perros macho" value: 
						perros_macho count (each.edad_categoria = "cachorro")+ 
						perros_macho count(each.edad_categoria = "adulto") + 
						perros_macho count(each.edad_categoria = "senior");
						data "perros hembra" value:
						perros_hembra count(each.edad_categoria = "cachorro")+
						perros_hembra count(each.edad_categoria = "adulto")+
						perros_hembra count(each.edad_categoria = "senior");
							
							
					}
				}
				
				display pie1 refresh: every(10#cycles)  type: 2d {
					chart "Total de perros por edad" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
						data "cachorro" value: perros_macho count (each.edad_categoria="cachorro") + perros_hembra count(each.edad_categoria = "cachorro") color: #limegreen ;
						data "adulto" value: perros_macho count (each.edad_categoria="adulto") + perros_hembra count(each.edad_categoria = "adulto")color: #gamaorange ;
						data "senior" value: perros_macho count (each.edad_categoria="senior") + perros_hembra count(each.edad_categoria = "senior")color: #tomato;
					}
				}
				display pie2 refresh: every(10#cycles)  type: 2d {
					chart "Perros macho" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
						data "cachorro" value: perros_macho count (each.edad_categoria = "cachorro")color: #limegreen;
						data "adulto" value: perros_macho count (each.edad_categoria = "adulto")color: #gamaorange;
						data "senior" value: perros_macho count (each.edad_categoria = "senior")color: #tomato;
					}
				}
				
				display pie3 refresh: every(10#cycles)  type: 2d {
					chart "Perros hembra" type: pie style: exploded size: {1, 0.5} position: {0, 0.5} {
						data "cachorro" value: perros_hembra count (each.edad_categoria = "cachorro")color: #limegreen;
						data "adulto" value: perros_hembra count (each.edad_categoria = "adulto")color: #gamaorange;
						data "senior" value: perros_hembra count (each.edad_categoria = "senior")color: #tomato;
					}
				}
				
				
				display pie4 refresh: every(10#cycles)  type: 2d {
					chart "Perros actuales hembra Esterilizacion" type: pie style: exploded size: {1, 0.5} position: {0, 0.5} {
						data "esterilizados" value: perros_hembra count (each.esterilizado = true)color: #black;
						data "no esterilizados" value: perros_hembra count (each.esterilizado = false)color: #white;
					}
				}
				
				display pie4 refresh: every(10#cycles)  type: 2d {
					chart "Perros historico hembra Esterilizacion" type: pie style: exploded size: {1, 0.5} position: {0, 0.5} {
						data "esterilizados" value: total_perros_esterilizados color: #black;
						data "no esterilizados" value: total_perros - total_perros_esterilizados color: #white;
					}
				}
				
					
				}
				
				}
