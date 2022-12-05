class CitationSupplyingService
  # TODO: implement error msg in operation outcome

  def find_by_project_id(project_id)
    citations = Project
                .find(project_id)
                .citations
                .includes(:authors, :journal, authors_citations: :author)
                .all
    create_bundle(objs = citations, type = 'collection')
  end

  def find_by_citation_id(citation_id)
    citation = Citation.find(citation_id)
    citation_in_fhir = create_fhir_obj(citation)

    return citation_in_fhir.validate unless citation_in_fhir.valid?

    citation_in_fhir
  end

  private

  def create_bundle(objs, type)
    bundle = {
      'type' => type,
      'entry' => []
    }

    for obj in objs do
      fhir_obj = create_fhir_obj(obj)
      bundle['entry'].append({ 'resource' => fhir_obj }) if fhir_obj.valid?
    end

    FHIR::Bundle.new(bundle)
  end

  def create_fhir_obj(raw)
    citation = {
      'status' => 'active',
      'id' => raw.id,
      'citedArtifact' => {
        'identifier' => [],
        'title' => [],
        'abstract' => [],
        'publicationForm' => [],
        'contributorship' => {
          'entry' => []
        }
      }
    }

    authors = raw.authors
    for i in authors.size.times do
      author = {
        'resourceType' => 'Practitioner',
        'id' => 'author' + i.to_s,
        'name' => {
          'text' => authors[i]['name']
        }
      }
      entry = {
        'contributor' => {
          'reference' => '#author' + i.to_s
        }
      }
      if citation['contained']
        citation['contained'].append(author)
      else
        citation['contained'] = [author]
      end
      citation['citedArtifact']['contributorship']['entry'].append(entry)
    end

    journal = raw.journal
    if journal
      journal_info = {
        'publicationDateYear' => journal.publication_date,
        'volume' => journal.volume,
        'issue' => journal.issue,
        'publishedIn' => {
          'title' => journal.name
        }
      }
      citation['citedArtifact']['publicationForm'].append(journal_info)
    end

    title = raw.name
    if title
      citation['citedArtifact']['title'].append({
                                                  'text' => title
                                                })
    end

    abstract = raw.abstract
    if abstract
      citation['citedArtifact']['abstract'].append({
                                                     'text' => abstract
                                                   })
    end

    pmid = raw.pmid
    if pmid
      citation['citedArtifact']['identifier'].append({
                                                       'system' => 'https://pubmed.ncbi.nlm.nih.gov',
                                                       'value' => pmid
                                                     })
    end

    FHIR::Citation.new(citation)
  end
end
