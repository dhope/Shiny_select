library(shiny)

# Define UI for data upload app ----
ui <- fluidPage(
  
  # App title ----
  titlePanel("Assign tasks for WildTrax"),
  
  # Sidebar layout with input and output definitions ----
  sidebarLayout(
    
    # Sidebar panel for inputs ----
    sidebarPanel(
      
      textInput("randomseed", "Random seed number", value = 123456),
      
      # Input: Select a file ----
      fileInput("file1", "Upload empty tasks file",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv")),
      fileInput("file2", "Upload pre-filed hours",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv")),
      
      # Horizontal line ----
      tags$hr(), 
        textInput(inputId = "transcriber",
                  label = "transcriber", 
                  value = "Name as in WildTrax",
                  placeholder = "Name should match that in WildTrax system"),
        textInput(inputId = "hrs",
                  label = "Hours", 
                  value = "Number of hours",
                  placeholder = "Should be a numeric value. Can be decimals"),
        
        actionButton("Add", "Add hours to transcribe"),
      
      # Input: Checkbox if file has header ----
      # checkboxInput("header", "Header", TRUE),
      
      # Input: Select separator ----
      # radioButtons("sep", "Separator",
      #              choices = c(Comma = ",",
      #                          Semicolon = ";",
      #                          Tab = "\t"),
      #              selected = ","),
      # 
      # # Input: Select quotes ----
      # radioButtons("quote", "Quote",
      #              choices = c(None = "",
      #                          "Double Quote" = '"',
      #                          "Single Quote" = "'"),
      #              selected = '"'),
      # 
      # # Horizontal line ----
      # tags$hr(),
      # 
      # # Input: Select number of rows to display ----
      # radioButtons("disp", "Display",
      #              choices = c(Head = "head",
      #                          All = "all"),
      #              selected = "head"),
      tags$hr(),
      # Button
      downloadButton("downloadData", "Download assigned tasks")
      
    )  ,
    
    # Main panel for displaying outputs ----
    mainPanel(
      
      # Output: Data file ----
      # tableOutput("contents"),
      
      tabsetPanel(
        tabPanel("Interpreter Hours", tableOutput(outputId = "table")),
        tabPanel("Assigned Hours", tableOutput(outputId = "summary"))
        # tabPanel("Uploaded File", tableOutput("contents"))
        )
      
    )
    
  )
)

# Define server logic to read selected file ----
server <- function(input, output) {
  
  uploaded_file <- reactive({
    
    # input$file1 will be NULL initially. After the user selects
    # and uploads a file, head of that data file by default,
    # or all rows if selected, will be shown.
    
    req(input$file1)
    
    # when reading semicolon separated files,
    # having a comma separator causes `read.csv` to error
    tryCatch(
      {
        df <- readr::read_csv(input$file1$datapath,
                              col_types = readr::cols(.default = "c"),
                              na = character()) |> 
          as.data.frame()
      },
      error = function(e) {
        # return a safeError if a parsing error occurs
        stop(safeError(e))
      }
    )
      return(df)
    
    
  })
  uploaded_tasks_file <- reactive({
    
    # input$file1 will be NULL initially. After the user selects
    # and uploads a file, head of that data file by default,
    # or all rows if selected, will be shown.
    
    req(input$file2)
    
    # when reading semicolon separated files,
    # having a comma separator causes `read.csv` to error
    tryCatch(
      {
        df <- readr::read_csv(input$file2$datapath,
                              col_types = readr::cols()) 
        
      },
      error = function(e) {
        # return a safeError if a parsing error occurs
        stop(safeError(e))
      }
    )
    return(df)
    
    
  })
  output$contents <- renderDataTable(uploaded_file())
  
 assigned_tasks <- reactive(
    withr::with_seed(input$randomseed,{
      uploaded_file() |>
        tibble::as_tibble() |> 
        dplyr::filter(transcriber=="Not Assigned") |> 
        dplyr::mutate(transcriber = sample(
          table_df()$transcriber,
          size = dplyr::n(),
          replace =T, 
          prob = table_df()$phrs ))
    })
    
  )
  
  # Downloadable csv of selected dataset ----
  output$downloadData <- downloadHandler(
    filename = function() {
      paste(stringr::str_replace(input$file1$name, ".csv", "_assigned_tasks"), ".csv", sep = "")
    },
    content = function(file) {
     readr::write_csv(download_dataset(), file)
    }
  )
  
  rv <- reactiveValues(
    df = data.frame(
      transcriber = character(),
      hrs = as.numeric(character())
    )
  )
  
  observeEvent(input$file2,
               rv$df <- rbind(rv$df, 
                              uploaded_tasks_file()) 
               )
  
  
  observeEvent(input$Add, {
    rv$df <- rbind(rv$df, 
                   data.frame(
                     transcriber = input$transcriber, 
                     hrs = as.numeric(input$hrs))) 
  })
  
  table_df <- reactive({
    rv$df |> 
      dplyr::filter(!is.na(hrs)) |> 
      dplyr::mutate(phrs = hrs/sum(hrs))
  })
  
  output$table<-renderTable({
    rv$df  
  })
  
  download_dataset <- reactive({
    uploaded_file()|> 
      dplyr::filter(transcriber!="Not Assigned") |> 
      dplyr::bind_rows(assigned_tasks())
  }
  )
  
  output$summary <- renderTable({
    assigned_tasks() |> 
      dplyr::summarize(hrs_assigned = sum(as.numeric(taskLength))/60/60, .by = transcriber) |> 
      dplyr::left_join(table_df(),
                       by = dplyr::join_by(transcriber)) |> 
      dplyr::select(Transcriber = transcriber, `Hours entered` = hrs, `Hours assigned` = hrs_assigned,
                    `Proportion entered` = phrs) |> 
      dplyr::mutate(
        `Prortion given` = `Hours assigned`/sum(`Hours assigned`),
        `Remaining hours` = `Hours entered`-`Hours assigned`) 
  })
  
}

# Create Shiny app ----
shinyApp(ui, server)