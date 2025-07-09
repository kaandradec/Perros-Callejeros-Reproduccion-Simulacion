model code_simulation

global {
	

//	shape_file road_file <- shape_file("../maps/plaza_calles.shp"); //fixed not whole mayondon
//	shape_file building_file <- shape_file("../maps/plaza_const.shp"); //fixed not whole mayondon

	shape_file road_file <- shape_file("../maps/try road.shp"); //fixed not whole mayondon
	shape_file building_file <- shape_file("../maps/buildings.shp"); //fixed not whole mayondon

	geometry shape <- envelope(road_file);
	graph road_network;
	
	int numeros_perros_macho <- 25; // Número inicial de perros macho
	int numeros_perro_hembra <- 25; // Número inicial de perros hembra
	float velocidad_agente <- 4 #km / #h;
	float probabilidad_crianza <- 0.02; //Probabilidad de reproducirse (breed) cuando se cumple la condición 
	//(por ejemplo, macho encuentra hembra adulta). En cada oportunidad de cruce, se evalúa un flip(probabilidad_crianza) para decidir si efectivamente ocurre la reproducción.
	float step <- 1440 #mn;
	int numero_fuentes_comida <- 5; //Cantidad de fuentes de comida a crear en el entorno. Cada fuente de comida se ubica en un punto de la red.
	int umbral_hambre <- 300; //Umbral de “hambre” a partir del cual el agente buscará comida. Cuando decide buscar comida.
	// En reflex when_hungry, se evalúa hunger >= when_hungry_get_food para dirigir al agente hacia una fuente de comida.
	int umbral_muerte_hambre <- 700; //Umbral de hambre máximo: si hunger = die_when_hungry, el agente muere de hambre.
	int max_crias_global <- 6; //Número máximo global de crías en una camada.
	// En el código dentro de la acción breed, se usa rnd(1, max_offspring) para decidir cuántas crías nacerán en esa reproducción.
	float probabilidad_muerte_accidental <- 0.0001; //Probabilidad de muerte accidental en cada ciclo/reflex. 

	
	
	


	init {
		create calles from: road_file;
		create construcciones from: building_file;
		road_network <- as_edge_graph(calles);
		
		
		create fuente_comida number: numero_fuentes_comida{
			location <- one_of(road_network);
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
	}
	
	
}


species fuente_comida{
	rgb color <- #red;	
	
	 aspect cuadrado {
        // Dibuja un cuadrado de lado 10 unidades. Ajusta 10 al tamaño que necesites.
        draw square(20) color: #red;
    }
}

species perros_hembra skills: [moving]{
	int hambre;
	int edad;
	string edad_categoria;rgb color <- #pink;
	point target <- nil;
	int total_crias <- rnd(70, 120);
	int max_crias_individual <- rnd(3, 6);
	int crias_actuales;
	int numero_crias;

	
	//365 = 1 year
	
	reflex incrementar_edad {
		edad <- edad + 1;
		
		if (edad = 1){
			edad_categoria <- "cachorro";
		}
		if (edad = 1095){//3years
			edad_categoria <- "adulto";
		}
		if (edad = 3650){
			edad_categoria <- "senior";
		}
	}
	
	reflex aumentar_hambre {
        hambre <- hambre + 1; // Increment hunger by 1
    }
   
    reflex buscar_comida when: hambre >= umbral_hambre {
    	target <- point(one_of(fuente_comida));
    	if location = target{
    		hambre <- 0;
    	}
    }
    
    reflex deambular when: hambre <= umbral_hambre {
    	target <- any_location_in(one_of(construcciones));
    }
    
    reflex muere_por_hambre when: hambre = umbral_muerte_hambre{
    	write "Perro Hembra: muere por hambre";
    	do die;
    }
    
    reflex muere_por_vejez when: edad = 5110{
    	write "Perro Hembra: muere por vejez" ;
		do die;
	}
	reflex muerte_accidental when: flip(probabilidad_muerte_accidental) {
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
		draw sphere(5) color:  #pink;
}

	
  // Atributo para controlar si ya no puede tener más crías
bool no_puede_criar_mas <- false;

	action reproducirse {
		if edad_categoria = "adulto" {
			numero_crias <- rnd(1, max_crias_global);
			int nb_female_offsprings <- rnd(0, numero_crias);
    		int nb_male_offsprings <- numero_crias - nb_female_offsprings;
			create species(perros_hembra) number: nb_female_offsprings  {
				edad <- 1;
				hambre <- 0;
				edad_categoria <- "cachorro";
				speed <- velocidad_agente;
				location <- myself;
				}
			create species(perros_macho) number: nb_male_offsprings {
        		edad <- 1;
        		hambre <- 0;
        		edad_categoria <- "cachorro";
        		speed <- velocidad_agente;
				location <- myself;
		}
	}
		
	}
	
}



species perros_macho skills: [moving] {
	int hambre <- 0;
	int edad;
	string edad_categoria;
	rgb color <- #blue;
	point target <- nil;
	

	//365 = 1 year
	reflex incrementar_edad {
		edad <- edad + 1;
		if (edad = 1){
			edad_categoria <- "cachorro";
		}
		if (edad = 365){
			edad_categoria <- "adulto";
		}
		if (edad = 3650){
			edad_categoria <- "senior";
		}
	}
	
	
	// Actions that might increase hunger
	reflex aumentar_hambre {
        hambre <- hambre + 1; // Increment hunger by 1
    }
    
   // Reflex para buscar comida cuando está hambriento
    reflex buscar_comida when: hambre >= umbral_hambre {
    	target <- point(one_of(fuente_comida));
    	if location = target{
    		hambre <- 0;
    	}
    }
    
    // Reflex para moverse al azar cuando no está hambriento
    reflex deambular when: hambre <= umbral_hambre {
    	target <- any_location_in(one_of(construcciones));
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
	
	reflex reproducirse when: edad_categoria = "adulto"{
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
	parameter "Numero inicial de perros macho" var: numeros_perros_macho min: 0 max: 200;
	parameter "Numero inicial de perros hembra" var: numeros_perro_hembra min: 0 max: 200;
	parameter "Probabilidad de reproducción" var: probabilidad_crianza min: 0.0 max: 0.5;
	parameter "Número de fuentes de comida" var: numero_fuentes_comida min: 0 max: 20;
	parameter "Humbral hambre" var: umbral_hambre min: 0 max: 500; // Valores bajos: busca pronto, bajo riesgo de inanición. Valores altos: busca tarde, mayor riesgo de no llegar a tiempo.
	parameter "Humbral muerte por hambre" var: umbral_muerte_hambre min: 0 max: 2000; // Valores bajos: muere con poco hambre, supervivencia corta. Valores altos: aguanta más tiempo sin comer, menor mortalidad por hambre.
	parameter "Velocidad de los perros" var: velocidad_agente min: 0.0 max: 1.0;
	parameter "Probabilidad de muerte accidental" var: probabilidad_muerte_accidental min: 0.000001 max: 0.0005 ;


	
	output {
		display map_2D type: 2d {
			
				species construcciones transparency: 0.8;
				species calles aspect: base;
				species perros_macho aspect: sphere;
				species perros_hembra aspect: sphere;
				species fuente_comida aspect: cuadrado;
				
				}
				display another_chart type: 2d refresh: every(10 #cycles){
					chart "Conteo de agentes" type: series{
						data "cachorro" value: perros_macho count (each.edad_categoria="cachorro")  color: #magenta ;
						data "adulto" value: perros_macho count (each.edad_categoria="adulto") color: #blue ;
						data "senior" value: perros_macho count (each.edad_categoria="senior") color: #red;
					}
				}
				display total_cats type: 2d refresh: every(10 #cycles){
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
				display chart2 refresh: every(10#cycles) type:2d{
						chart "Conteo por generos" type: series {
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
						data "cachorro" value: perros_macho count (each.edad_categoria="cachorro") + perros_hembra count(each.edad_categoria = "cachorro") color: #magenta ;
						data "adulto" value: perros_macho count (each.edad_categoria="adulto") + perros_hembra count(each.edad_categoria = "adulto")color: #blue ;
						data "senior" value: perros_macho count (each.edad_categoria="senior") + perros_hembra count(each.edad_categoria = "senior")color: #red;
					}
					}
					display pie2 refresh: every(10#cycles)  type: 2d {
					chart "Categorias perros macho" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
						data "cachorro" value: perros_macho count (each.edad_categoria = "cachorro");
						data "adulto" value: perros_macho count (each.edad_categoria = "adulto");
						data "senior" value: perros_macho count (each.edad_categoria = "senior");
					}
					
					}
					display pie3 refresh: every(10#cycles)  type: 2d {
					chart "Categorias perros hembra" type: pie style: exploded size: {1, 0.5} position: {0, 0.5} {
						data "cachorro" value: perros_hembra count (each.edad_categoria = "cachorro");
						data "adulto" value: perros_hembra count (each.edad_categoria = "adulto");
						data "senior" value: perros_hembra count (each.edad_categoria = "senior");
					}
					
					}
					

				}
				
				
				}
